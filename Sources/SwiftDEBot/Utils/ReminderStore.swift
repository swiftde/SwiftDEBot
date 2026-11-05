import Foundation
import Logging

/// A reminder set with `!remindme`, due to be delivered as a reply to the message that set it.
struct Reminder: Codable, Equatable, Sendable {
  var id = UUID()
  let userID: String
  let channelID: String
  let messageID: String
  let guildID: String?
  let dueDate: Date
  let text: String?
}

enum ReminderStoreError: Error, Equatable {
  case tooManyReminders
}

/// Keeps the pending reminders in a JSON file so they survive restarts, and delivers each one when it is due.
actor ReminderStore {
  static let maxRemindersPerUser = 5

  typealias Deliver = @Sendable (Reminder) async -> Void

  private let fileURL: URL
  private let logger = Logger(label: "swiftde.bot.reminders")
  private var reminders: [Reminder] = []
  private var timers: [UUID: Task<Void, Never>] = [:]
  private var deliver: Deliver?

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  /// Loads the saved reminders and schedules them. Reminders that came due while the bot was down are delivered right
  /// away. A file that cannot be decoded is moved aside to `<name>.corrupt` and the store starts empty.
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

  func add(_ reminder: Reminder) throws {
    guard reminders(of: reminder.userID).count < Self.maxRemindersPerUser else {
      throw ReminderStoreError.tooManyReminders
    }
    reminders.append(reminder)
    save()
    schedule(reminder)
  }

  /// Removes the user's reminder at a 1-based `position` in `reminders(of:)`. Returns nil if there is none.
  func remove(position: Int, of userID: String) -> Reminder? {
    let own = reminders(of: userID)
    guard own.indices.contains(position - 1) else { return nil }
    let reminder = own[position - 1]
    remove(id: reminder.id)
    return reminder
  }

  private func remove(id: UUID) {
    timers.removeValue(forKey: id)?.cancel()
    reminders.removeAll { $0.id == id }
    save()
  }

  private func schedule(_ reminder: Reminder) {
    timers[reminder.id] = Task { [weak self] in
      let delay = reminder.dueDate.timeIntervalSinceNow
      if delay > 0 {
        do { try await Task.sleep(for: .seconds(delay)) } catch { return }
      }
      await self?.fire(reminder)
    }
  }

  private func fire(_ reminder: Reminder) async {
    guard reminders.contains(where: { $0.id == reminder.id }) else { return }
    // Removed before delivery so that a crash during delivery cannot repeat the reminder after a restart.
    timers[reminder.id] = nil
    reminders.removeAll { $0.id == reminder.id }
    save()
    await deliver?(reminder)
  }

  private func load() -> [Reminder] {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
    do {
      let data = try Data(contentsOf: fileURL)
      return try Self.makeDecoder().decode([Reminder].self, from: data)
    } catch {
      let corruptURL = fileURL.appendingPathExtension("corrupt")
      logger.error("Could not read reminders from \(fileURL.path), moving it to \(corruptURL.path): \(error)")
      try? FileManager.default.removeItem(at: corruptURL)
      try? FileManager.default.moveItem(at: fileURL, to: corruptURL)
      return []
    }
  }

  private func save() {
    do {
      // .atomic writes a temporary file and renames it, so a crash cannot leave a half-written file.
      try Self.makeEncoder().encode(reminders).write(to: fileURL, options: .atomic)
    } catch {
      logger.error("Could not save reminders to \(fileURL.path): \(error)")
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
