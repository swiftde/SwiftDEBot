import DiscordBM
import Foundation

/// What a `!remindme` message asks for.
enum RemindMeRequest: Equatable {
  static let minimumSeconds: Double = 30
  static let maximumSeconds: Double = 30 * 86_400
  static let maximumTextLength = 100

  case list
  case delete(position: Int)
  case create(seconds: Double, text: String?)
  /// The request cannot be fulfilled; the associated text tells the user why.
  case invalid(String)

  static let usage =
    "Beispiele: `!remindme 2,5h Pizza aus dem Ofen`, `!remindme 10 min`, `!remindme 1h 30m Meeting`."

  init(argument: String?) {
    guard let argument else {
      self = .list
      return
    }

    let words = argument.split(whereSeparator: \.isWhitespace)
    if let first = words.first, ["löschen", "loeschen", "delete"].contains(first.lowercased()) {
      if words.count == 2, let position = Int(words[1]), position > 0 {
        self = .delete(position: position)
      } else {
        self = .invalid("Gib die Nummer des Reminders an, z. B. `!remindme löschen 2`.")
      }
      return
    }

    guard let (seconds, rest) = parseLeadingDuration(argument) else {
      self = .invalid("Ich verstehe die Dauer nicht. \(Self.usage)")
      return
    }
    guard seconds >= Self.minimumSeconds else {
      self = .invalid("Die Dauer muss mindestens 30 Sekunden betragen.")
      return
    }
    guard seconds <= Self.maximumSeconds else {
      self = .invalid("Die Dauer darf höchstens 30 Tage betragen.")
      return
    }
    guard rest.count <= Self.maximumTextLength else {
      self = .invalid("Der Text darf höchstens \(Self.maximumTextLength) Zeichen lang sein.")
      return
    }
    self = .create(seconds: seconds, text: rest.isEmpty ? nil : rest)
  }
}

/// The text of a delivered reminder. A reminder delivered more than a minute late says so.
func reminderDeliveryText(for reminder: Reminder, now: Date) -> String {
  var text = "⏰ \(DiscordUtils.userMention(id: reminder.userID)) Erinnerung"
  text += reminder.text.map { ": \($0)" } ?? "!"
  let delay = Int(now.timeIntervalSince(reminder.dueDate))
  if delay > 60 {
    text += " (verspätet um \(germanDurationDescription(seconds: delay)))"
  }
  return text
}

/// The text listing a user's pending reminders, numbered as `!remindme löschen` expects.
func reminderListText(for reminders: [Reminder], now: Date) -> String {
  guard !reminders.isEmpty else { return "Du hast keine offenen Reminder." }
  let lines = reminders.enumerated().map { offset, reminder in
    let remaining = germanDurationDescription(seconds: Int(reminder.dueDate.timeIntervalSince(now).rounded(.up)))
    return "\(offset + 1). in \(remaining) – \(reminder.text ?? "(ohne Text)")"
  }
  return "Deine Reminder:\n" + lines.joined(separator: "\n")
}

struct RemindMeCommand: MessageCommand {
  let helpText =
    "`!remindme <dauer> [text]`: Erinnert dich nach der Dauer, z. B. `!remindme 2,5h Pizza`. "
    + "`!remindme` listet deine Reminder, `!remindme löschen <nr>` löscht einen."

  let store: ReminderStore

  func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
    guard let invocation = message.content.invocation(of: "!remindme"), let author = message.author else { return }

    switch RemindMeRequest(argument: invocation.argument) {
    case .list:
      let text = reminderListText(for: await store.reminders(of: author.id), now: Date())
      try await reply(text, to: message, client: client)
    case .delete(let position):
      if await store.remove(position: position, of: author.id) != nil {
        try await reply("Reminder \(position) gelöscht.", to: message, client: client)
      } else {
        try await reply("Du hast keinen Reminder Nr. \(position).", to: message, client: client)
      }
    case .create(let seconds, let text):
      let reminder = Reminder(
        userID: author.id,
        channelID: message.channel_id,
        messageID: message.id,
        guildID: message.guild_id,
        dueDate: Date().addingTimeInterval(seconds),
        text: text
      )
      do {
        try await store.add(reminder)
        try await client.addReaction(.unicodeEmoji("⏰"), to: message.id, in: message.channel_id)
      } catch ReminderStoreError.tooManyReminders {
        try await reply(
          "Du hast schon \(ReminderStore.maxRemindersPerUser) offene Reminder. "
            + "Mit `!remindme` siehst du sie, mit `!remindme löschen <nr>` löschst du einen.",
          to: message, client: client)
      }
    case .invalid(let explanation):
      try await reply(explanation, to: message, client: client)
    }
  }

  /// Replies without pinging anyone, since the text may repeat what users wrote.
  private func reply(_ text: String, to message: Gateway.MessageCreate, client: DiscordClient) async throws {
    try await client.createMessage(
      channelId: message.channel_id,
      payload: .init(
        content: text,
        allowed_mentions: .init(parse: [], roles: [], users: [], replied_user: false),
        message_reference: .init(message_id: message.id, fail_if_not_exists: false)
      )
    ).guardSuccess()
  }
}

extension DiscordClient {
  /// Delivers a due reminder as a reply to the message that set it, pinging only its author. If that message was
  /// deleted, Discord sends it as a plain message instead.
  func deliverReminder(_ reminder: Reminder) async throws {
    try await createMessage(
      channelId: reminder.channelID,
      payload: .init(
        content: reminderDeliveryText(for: reminder, now: Date()),
        allowed_mentions: .init(parse: [], roles: [], users: [reminder.userID], replied_user: true),
        message_reference: .init(
          message_id: reminder.messageID,
          channel_id: reminder.channelID,
          guild_id: reminder.guildID,
          fail_if_not_exists: false
        )
      )
    ).guardSuccess()
  }
}
