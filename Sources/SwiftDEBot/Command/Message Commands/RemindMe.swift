import DiscordBM
import Foundation

/// What a `!remindme` message asks for.
enum RemindMeRequest: Equatable {
  static let minimumSeconds: Double = 30
  static let maximumSeconds: Double = 30 * 86_400
  static let maximumTextLength = 100

  case list
  case delete(number: Int)
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
      if words.count == 2, let number = Int(words[1]), number > 0 {
        self = .delete(number: number)
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
    // Counted in scalars like Discord's message limit, since one visible character can be many of them.
    guard rest.unicodeScalars.count <= Self.maximumTextLength else {
      self = .invalid("Der Text darf höchstens \(Self.maximumTextLength) Zeichen lang sein.")
      return
    }
    self = .create(seconds: seconds, text: rest.isEmpty ? nil : rest)
  }
}

/// Who a due reminder pings: its author, then everyone who joined by reacting. Bots are skipped because the bot's own
/// reaction is among them.
func reminderRecipients(authorID: String, reactors: [DiscordUser]) -> [String] {
  var recipients = [authorID]
  for reactor in reactors where reactor.bot != true && !recipients.contains(reactor.id) {
    recipients.append(reactor.id)
  }
  return recipients
}

/// The text of a delivered reminder. A reminder delivered more than a minute late says so.
func reminderDeliveryText(for reminder: Reminder, recipients: [String], now: Date) -> String {
  let mentions = recipients.map { DiscordUtils.userMention(id: $0) }.joined(separator: " ")
  var text = "⏰ \(mentions) Erinnerung"
  text += reminder.text.map { ": \($0)" } ?? "!"
  let delay = Int(now.timeIntervalSince(reminder.dueDate))
  if delay > 60 {
    text += " (verspätet um \(germanDurationDescription(seconds: delay)))"
  }
  if let url = reminder.referencedMessageURL {
    text += "\n\(url)"
  }
  return text
}

/// The text listing a user's pending reminders. It spells out `Nr.` because Discord renders `2.` as a Markdown list and
/// renumbers it, while these numbers may be out of order.
func reminderListText(for reminders: [Reminder], now: Date) -> String {
  guard !reminders.isEmpty else { return "Du hast keine offenen Reminder." }
  let lines = reminders.map { reminder in
    let remaining = germanDurationDescription(seconds: Int(reminder.dueDate.timeIntervalSince(now).rounded(.up)))
    let link = reminder.referencedMessageURL.map { " \($0)" } ?? ""
    return "Nr. \(reminder.number): in \(remaining) – \(reminder.text ?? "(ohne Text)")\(link)"
  }
  return "Deine Reminder:\n" + lines.joined(separator: "\n")
}

private let reminderEmoji = "⏰"

struct RemindMeCommand: MessageCommand {
  let helpText =
    "`!remindme <dauer> [text]`: Erinnert dich nach der Dauer, z. B. `!remindme 2,5h Pizza`. "
    + "Als Antwort verlinkt er die Nachricht, und wer mit ⏰ reagiert, wird mit erinnert. "
    + "`!remindme` listet deine Reminder, `!remindme löschen <nr>` löscht einen."

  let store: ReminderStore

  func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
    guard let invocation = message.content.invocation(of: "!remindme"), let author = message.author else { return }

    switch RemindMeRequest(argument: invocation.argument) {
    case .list:
      let text = reminderListText(for: await store.reminders(of: author.id), now: Date())
      try await reply(text, to: message, client: client)
    case .delete(let number):
      let text: String
      do {
        let removed = try await store.remove(number: number, of: author.id) != nil
        text = removed ? "Reminder \(number) gelöscht." : "Du hast keinen Reminder Nr. \(number)."
      } catch {
        text = "Ich konnte den Reminder nicht löschen, bitte versuch es später nochmal."
      }
      try await reply(text, to: message, client: client)
    case .create(let seconds, let text):
      let reminder = Reminder(
        userID: author.id,
        channelID: message.channel_id,
        messageID: message.id,
        guildID: message.guild_id,
        referencedMessageID: message.type == .reply ? message.message_reference?.message_id : nil,
        dueDate: Date().addingTimeInterval(seconds),
        text: text
      )
      do {
        try await store.add(reminder)
      } catch ReminderStoreError.tooManyReminders {
        try await reply(
          "Du hast schon \(ReminderStore.maxRemindersPerUser) offene Reminder. "
            + "Mit `!remindme` siehst du sie, mit `!remindme löschen <nr>` löschst du einen.",
          to: message, client: client)
        return
      } catch {
        try await reply(
          "Ich konnte den Reminder nicht speichern, bitte versuch es später nochmal.", to: message, client: client)
        return
      }
      try await client.addReaction(.unicodeEmoji(reminderEmoji), to: message.id, in: message.channel_id).guardSuccess()
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
  /// Delivers a due reminder as a reply to the message that set it, pinging only its recipients. If that message was
  /// deleted, Discord sends it as a plain message instead.
  func deliverReminder(_ reminder: Reminder) async throws {
    let recipients = reminderRecipients(authorID: reminder.userID, reactors: await reminderReactors(of: reminder))
    try await createMessage(
      channelId: reminder.channelID,
      payload: .init(
        content: reminderDeliveryText(for: reminder, recipients: recipients, now: Date()),
        allowed_mentions: .init(parse: [], roles: [], users: recipients, replied_user: true),
        message_reference: .init(
          message_id: reminder.messageID,
          channel_id: reminder.channelID,
          guild_id: reminder.guildID,
          fail_if_not_exists: false
        )
      )
    ).guardSuccess()
  }

  /// Reads the reactions only at delivery, so taking one back or reacting while the bot is down just works and nothing
  /// needs storing. DiscordBM drops the `limit` parameter, so this sees at most Discord's default of 25 users, which
  /// also keeps the mentions within the message length limit. Failing to read them, for example because the message
  /// was deleted, only narrows the reminder to its author.
  private func reminderReactors(of reminder: Reminder) async -> [DiscordUser] {
    do {
      return try await listMessageReactionsByEmoji(
        channelId: reminder.channelID, messageId: reminder.messageID, emoji: .unicodeEmoji(reminderEmoji)
      ).decode()
    } catch {
      log.warning("Could not read reactions for reminder \(reminder.id): \(error)")
      return []
    }
  }
}
