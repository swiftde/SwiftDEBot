import Foundation
import Logging

/// A reminder set with `!remindme`, due to be delivered as a reply to the message that set it.
struct Reminder: Codable, Equatable, Sendable {
  var id = UUID()
  /// Identifies the reminder for `!remindme löschen`. Assigned by `ReminderStore.add` and stable until delivery, so a
  /// reminder firing in between cannot redirect a deletion to another one.
  var number = 0
  let userID: String
  let channelID: String
  let messageID: String
  let guildID: String?
  /// The message that `!remindme` replied to, if any.
  var referencedMessageID: String? = nil
  let dueDate: Date
  let text: String?

  /// Jump link to the referenced message.
  var referencedMessageURL: String? {
    referencedMessageID.map { "https://discord.com/channels/\(guildID ?? "@me")/\(channelID)/\($0)" }
  }
}

enum ReminderStoreError: Error, Equatable {
  case tooManyReminders
  case saveFailed
}

/// Keeps the pending reminders in a JSON file so they survive restarts, and delivers each one when it is due.
actor ReminderStore {
  static let maxRemindersPerUser = 5

  typealias Deliver = @Sendable (Reminder) async -> Void

  private let fileURL: URL
  private let logger = Logger(label: "swiftde.bot.reminders")
  private var reminders: [Reminder] = []
  private var deliver: Deliver?
  /// False if the file holds data the store could not read or move aside, which saving would destroy.
  private var canSave = true

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  /// Loads the saved reminders and schedules them. Reminders that came due while the bot was down are delivered right
  /// away. A file that cannot be decoded is moved aside to `<name>.corrupt` and the store starts empty. A file that cannot
  /// be read is left alone, and `add` fails until the next start.
  func start(deliver: @escaping Deliver) {
    self.deliver = deliver
    reminders = load()
    for reminder in reminders { schedule(reminder) }
    logger.info("Loaded \(reminders.count) reminder(s) from \(fileURL.path)")
  }

  /// The user's pending reminders, soonest first.
  func reminders(of userID: String) -> [Reminder] {
    reminders.filter { $0.userID == userID }.sorted { $0.dueDate < $1.dueDate }
  }

  /// Stores the reminder under the user's smallest free number and returns it with that number.
  @discardableResult
  func add(_ reminder: Reminder) throws -> Reminder {
    let taken = Set(reminders(of: reminder.userID).map(\.number))
    guard let number = (1...Self.maxRemindersPerUser).first(where: { !taken.contains($0) }) else {
      throw ReminderStoreError.tooManyReminders
    }
    var stored = reminder
    stored.number = number
    reminders.append(stored)
    guard save() else {
      reminders.removeLast()
      throw ReminderStoreError.saveFailed
    }
    schedule(stored)
    return stored
  }

  /// Removes the user's reminder with this number. Returns nil if there is none. If the file cannot be updated the
  /// reminder stays pending, because it would come back on the next start anyway.
  func remove(number: Int, of userID: String) throws -> Reminder? {
    guard let index = reminders.firstIndex(where: { $0.userID == userID && $0.number == number }) else { return nil }
    let reminder = reminders.remove(at: index)
    guard save() else {
      reminders.insert(reminder, at: index)
      throw ReminderStoreError.saveFailed
    }
    return reminder
  }

  /// The task of a deleted reminder sleeps on and `fire` ignores it. Cancelling would make `Task.sleep` throw, and
  /// Swift Testing segfaults capturing a backtrace of that throw on x86_64 Linux.
  private func schedule(_ reminder: Reminder) {
    Task { [weak self] in
      let delay = reminder.dueDate.timeIntervalSinceNow
      if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
      await self?.fire(reminder)
    }
  }

  private func fire(_ reminder: Reminder) async {
    guard reminders.contains(where: { $0.id == reminder.id }) else { return }
    // Removed before delivery so that a crash during delivery cannot repeat the reminder after a restart.
    reminders.removeAll { $0.id == reminder.id }
    save()
    await deliver?(reminder)
  }

  private func load() -> [Reminder] {
    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch CocoaError.fileReadNoSuchFile {
      return []
    } catch {
      logger.error("Could not read reminders from \(fileURL.path), not saving any until restart: \(error)")
      canSave = false
      return []
    }
    do {
      return try Self.makeDecoder().decode([Reminder].self, from: data)
    } catch {
      let corruptURL = fileURL.appendingPathExtension("corrupt")
      logger.error("Could not decode reminders in \(fileURL.path), moving it to \(corruptURL.path): \(error)")
      try? FileManager.default.removeItem(at: corruptURL)
      do {
        try FileManager.default.moveItem(at: fileURL, to: corruptURL)
      } catch {
        logger.error("Could not move \(fileURL.path), not saving any reminders until restart: \(error)")
        canSave = false
      }
      return []
    }
  }

  /// Returns whether the reminders reached the file. Failures are logged here.
  @discardableResult
  private func save() -> Bool {
    guard canSave else { return false }
    do {
      // .atomic writes a temporary file and renames it, so a crash cannot leave a half-written file.
      try Self.makeEncoder().encode(reminders).write(to: fileURL, options: .atomic)
      return true
    } catch {
      logger.error("Could not save reminders to \(fileURL.path): \(error)")
      return false
    }
  }

  private static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }

  private static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
