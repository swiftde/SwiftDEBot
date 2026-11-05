import Foundation
import PropertyBased
import Testing

@testable import SwiftDEBot

@Suite struct DurationParsingTests {
  @Test(arguments: [
    ("2,5h", 9_000.0, ""),
    ("2.5h Pizza", 9_000, "Pizza"),
    ("2,5 h", 9_000, ""),
    ("10 minuten Tee kochen", 600, "Tee kochen"),
    ("10 Minuten", 600, ""),
    ("1 Minute", 60, ""),
    ("45s", 45, ""),
    ("45 Sekunden", 45, ""),
    ("30 sek", 30, ""),
    ("1h30m", 5_400, ""),
    ("1h 30m Meeting", 5_400, "Meeting"),
    ("2 Std", 7_200, ""),
    ("1 Stunde", 3_600, ""),
    ("3d", 259_200, ""),
    ("2 Tage", 172_800, ""),
    ("1 Tag", 86_400, ""),
    ("1t", 86_400, ""),
    ("1H", 3_600, ""),
    ("10m3", 600, "3"),
    ("5 min, dann los", 300, ", dann los"),
  ])
  func parsesDurations(input: String, seconds: Double, rest: String) throws {
    let result = try #require(parseLeadingDuration(input))
    #expect(result.seconds == seconds)
    #expect(result.rest == rest)
  }

  @Test(arguments: ["", "10", "10 Tee", "5mal", "Pizza 10m", "h", ",5h", "2.h"])
  func rejectsNonDurations(input: String) {
    #expect(parseLeadingDuration(input) == nil)
  }

  @Test func readsWholeNumbersWithEveryUnit() async {
    let units: [(String, Int)] = [("s", 1), ("min", 60), ("stunden", 3_600), ("Tage", 86_400)]
    await propertyCheck(input: Gen.int(in: 0...10_000), Gen.int(in: 0...3), Gen.bool) { value, unitIndex, space in
      let unit = units[unitIndex]
      let input = "\(value)\(space ? " " : "")\(unit.0) Text"
      let result = parseLeadingDuration(input)
      #expect(result?.seconds == Double(value * unit.1))
      #expect(result?.rest == "Text")
    }
  }

  @Test func readsCommaAndPointAlike() async {
    await propertyCheck(input: Gen.int(in: 0...999), Gen.int(in: 0...99)) { whole, fraction in
      let comma = parseLeadingDuration("\(whole),\(fraction)h")
      let point = parseLeadingDuration("\(whole).\(fraction)h")
      #expect(comma != nil)
      #expect(comma?.seconds == point?.seconds)
    }
  }
}

@Suite struct GermanDurationDescriptionTests {
  @Test(arguments: [
    (0, "0 Sek"),
    (45, "45 Sek"),
    (90, "1 Min 30 Sek"),
    (600, "10 Min"),
    (8_040, "2 Std 14 Min"),
    (86_400, "1 Tag"),
    (2 * 86_400 + 3 * 3_600 + 120, "2 Tage 3 Std"),
    (-5, "0 Sek"),
  ])
  func describes(seconds: Int, description: String) {
    #expect(germanDurationDescription(seconds: seconds) == description)
  }
}

@Suite struct RemindMeRequestTests {
  @Test func listsWithoutArgument() {
    #expect(RemindMeRequest(argument: nil) == .list)
  }

  @Test(arguments: ["löschen 2", "Löschen 2", "loeschen 2", "delete 2"])
  func deletes(argument: String) {
    #expect(RemindMeRequest(argument: argument) == .delete(position: 2))
  }

  @Test(arguments: ["löschen", "löschen x", "löschen 0", "löschen 1 2"])
  func rejectsDeleteWithoutPosition(argument: String) {
    guard case .invalid = RemindMeRequest(argument: argument) else {
      Issue.record("expected invalid request")
      return
    }
  }

  @Test func createsWithText() {
    #expect(RemindMeRequest(argument: "2,5h Pizza aus dem Ofen") == .create(seconds: 9_000, text: "Pizza aus dem Ofen"))
  }

  @Test func createsWithoutText() {
    #expect(RemindMeRequest(argument: "30s") == .create(seconds: 30, text: nil))
  }

  @Test(arguments: ["29s", "0m", "31d", "30d 1s", "Pizza", "10", "1h " + String(repeating: "x", count: 101)])
  func rejects(argument: String) {
    guard case .invalid = RemindMeRequest(argument: argument) else {
      Issue.record("expected invalid request for \(argument)")
      return
    }
  }

  @Test func acceptsLimits() {
    #expect(RemindMeRequest(argument: "30d") == .create(seconds: 30 * 86_400, text: nil))
    let text = String(repeating: "x", count: 100)
    #expect(RemindMeRequest(argument: "1h \(text)") == .create(seconds: 3_600, text: text))
  }
}

@Suite struct ReminderTextTests {
  let now = Date(timeIntervalSince1970: 1_800_000_000)

  func reminder(dueIn seconds: Double, text: String?) -> Reminder {
    Reminder(
      userID: "42", channelID: "1", messageID: "2", guildID: nil, dueDate: now.addingTimeInterval(seconds), text: text)
  }

  @Test func deliversOnTime() {
    #expect(reminderDeliveryText(for: reminder(dueIn: 0, text: "Pizza"), now: now) == "⏰ <@42> Erinnerung: Pizza")
    #expect(reminderDeliveryText(for: reminder(dueIn: -30, text: nil), now: now) == "⏰ <@42> Erinnerung!")
  }

  @Test func mentionsDelay() {
    #expect(
      reminderDeliveryText(for: reminder(dueIn: -600, text: "Pizza"), now: now)
        == "⏰ <@42> Erinnerung: Pizza (verspätet um 10 Min)")
  }

  @Test func listsReminders() {
    #expect(reminderListText(for: [], now: now) == "Du hast keine offenen Reminder.")
    let list = reminderListText(
      for: [reminder(dueIn: 600, text: "Tee"), reminder(dueIn: 8_040, text: nil)], now: now)
    #expect(list == "Deine Reminder:\n1. in 10 Min – Tee\n2. in 2 Std 14 Min – (ohne Text)")
  }
}

@Suite struct ReminderStoreTests {
  let fileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("reminders-\(UUID().uuidString).json")

  func reminder(user: String = "42", dueIn seconds: Double, text: String? = nil) -> Reminder {
    // Whole seconds, because the file stores ISO 8601 dates without fractions.
    let due = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 + seconds).rounded())
    return Reminder(userID: user, channelID: "1", messageID: "2", guildID: "3", dueDate: due, text: text)
  }

  @Test func persistsAcrossInstances() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let first = ReminderStore(fileURL: fileURL)
    await first.start { _ in }
    let saved = reminder(dueIn: 3_600, text: "Pizza")
    try await first.add(saved)

    let second = ReminderStore(fileURL: fileURL)
    await second.start { _ in }
    #expect(await second.reminders(of: "42") == [saved])
  }

  @Test func limitsRemindersPerUser() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let store = ReminderStore(fileURL: fileURL)
    await store.start { _ in }
    for index in 0..<ReminderStore.maxRemindersPerUser {
      try await store.add(reminder(dueIn: 3_600 + Double(index)))
    }
    await #expect(throws: ReminderStoreError.tooManyReminders) {
      try await store.add(reminder(dueIn: 3_600))
    }
    try await store.add(reminder(user: "other", dueIn: 3_600))
  }

  @Test func removesByPositionInDueOrder() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let store = ReminderStore(fileURL: fileURL)
    await store.start { _ in }
    let later = reminder(dueIn: 7_200, text: "später")
    let sooner = reminder(dueIn: 3_600, text: "früher")
    try await store.add(later)
    try await store.add(sooner)

    #expect(await store.remove(position: 3, of: "42") == nil)
    #expect(await store.remove(position: 1, of: "other") == nil)
    #expect(await store.remove(position: 1, of: "42") == sooner)
    #expect(await store.reminders(of: "42") == [later])
  }

  @Test func deliversOverdueRemindersOnStart() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let overdue = reminder(dueIn: -600, text: "verpasst")
    let data = try {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      return try encoder.encode([overdue])
    }()
    try data.write(to: fileURL)

    let store = ReminderStore(fileURL: fileURL)
    let delivered = await withCheckedContinuation { continuation in
      Task { await store.start { continuation.resume(returning: $0) } }
    }
    #expect(delivered == overdue)
    #expect(await store.reminders(of: "42").isEmpty)
  }

  @Test func movesCorruptFileAside() async throws {
    let corruptURL = fileURL.appendingPathExtension("corrupt")
    defer {
      try? FileManager.default.removeItem(at: fileURL)
      try? FileManager.default.removeItem(at: corruptURL)
    }
    try Data("kaputt".utf8).write(to: fileURL)

    let store = ReminderStore(fileURL: fileURL)
    await store.start { _ in }
    #expect(await store.reminders(of: "42").isEmpty)
    #expect(try String(contentsOf: corruptURL, encoding: .utf8) == "kaputt")
  }
}
