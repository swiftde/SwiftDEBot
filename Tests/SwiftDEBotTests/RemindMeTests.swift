import DiscordBM
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
    #expect(RemindMeRequest(argument: argument) == .delete(number: 2))
  }

  @Test func deleteAddressesEveryPossibleNumber() async {
    await propertyCheck(input: Gen.int(in: 1...ReminderStore.maxRemindersPerUser)) { number in
      #expect(RemindMeRequest(argument: "löschen \(number)") == .delete(number: number))
    }
  }

  @Test(arguments: ["löschen", "löschen x", "löschen 0", "löschen 1 2"])
  func rejectsDeleteWithoutNumber(argument: String) {
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

  @Test(arguments: [
    "29s", "0m", "31d", "30d 1s", "Pizza", "10", "1h " + String(repeating: "x", count: 101),
    "1h " + String(repeating: "👨‍👩‍👧‍👦", count: 15),
  ])
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

  func reminder(
    dueIn seconds: Double, text: String?, number: Int = 1, guildID: String? = nil, referencedMessageID: String? = nil
  ) -> Reminder {
    Reminder(
      number: number, userID: "42", channelID: "1", messageID: "2", guildID: guildID,
      referencedMessageID: referencedMessageID, dueDate: now.addingTimeInterval(seconds), text: text)
  }

  @Test func deliversOnTime() {
    #expect(
      reminderDeliveryText(for: reminder(dueIn: 0, text: "Pizza"), recipients: ["42"], now: now)
        == "⏰ <@42> Erinnerung: Pizza")
    #expect(
      reminderDeliveryText(for: reminder(dueIn: -30, text: nil), recipients: ["42"], now: now)
        == "⏰ <@42> Erinnerung!")
  }

  @Test func mentionsDelay() {
    #expect(
      reminderDeliveryText(for: reminder(dueIn: -600, text: "Pizza"), recipients: ["42"], now: now)
        == "⏰ <@42> Erinnerung: Pizza (verspätet um 10 Min)")
  }

  @Test func mentionsDelayOnlyWhenMoreThanAMinuteLate() {
    #expect(
      reminderDeliveryText(for: reminder(dueIn: -60, text: "Pizza"), recipients: ["42"], now: now)
        == "⏰ <@42> Erinnerung: Pizza")
    #expect(
      reminderDeliveryText(for: reminder(dueIn: -61, text: "Pizza"), recipients: ["42"], now: now)
        == "⏰ <@42> Erinnerung: Pizza (verspätet um 1 Min 1 Sek)")
  }

  @Test func mentionsEveryRecipient() {
    #expect(
      reminderDeliveryText(for: reminder(dueIn: 0, text: nil), recipients: ["42", "7"], now: now)
        == "⏰ <@42> <@7> Erinnerung!")
  }

  @Test func mentionsRecipientsInGivenOrder() async {
    let recipients = Gen.int(in: 1...999_999).map { String($0) }.array(of: 1...6)
    await propertyCheck(input: recipients) { recipients in
      let mentions = recipients.map { "<@\($0)>" }.joined(separator: " ")
      #expect(
        reminderDeliveryText(for: reminder(dueIn: 0, text: "Pizza"), recipients: recipients, now: now)
          == "⏰ \(mentions) Erinnerung: Pizza")
    }
  }

  @Test func linksReferencedMessageInDelivery() {
    let replied = reminder(dueIn: 0, text: "Pizza", guildID: "3", referencedMessageID: "9")
    #expect(
      reminderDeliveryText(for: replied, recipients: ["42"], now: now)
        == "⏰ <@42> Erinnerung: Pizza\nhttps://discord.com/channels/3/1/9")
  }

  @Test func putsLinkAfterDelayNote() {
    let replied = reminder(dueIn: -600, text: "Pizza", guildID: "3", referencedMessageID: "9")
    #expect(
      reminderDeliveryText(for: replied, recipients: ["42"], now: now)
        == "⏰ <@42> Erinnerung: Pizza (verspätet um 10 Min)\nhttps://discord.com/channels/3/1/9")
  }

  @Test func listsReminders() {
    #expect(reminderListText(for: [], now: now) == "Du hast keine offenen Reminder.")
    let list = reminderListText(
      for: [reminder(dueIn: 600, text: "Tee", number: 1), reminder(dueIn: 8_040, text: nil, number: 2)], now: now)
    #expect(list == "Deine Reminder:\nNr. 1: in 10 Min – Tee\nNr. 2: in 2 Std 14 Min – (ohne Text)")
  }

  @Test func listShowsStoredNumbersInGivenOrder() {
    let list = reminderListText(
      for: [reminder(dueIn: 600, text: "Tee", number: 4), reminder(dueIn: 8_040, text: "Pizza", number: 2)], now: now)
    #expect(list == "Deine Reminder:\nNr. 4: in 10 Min – Tee\nNr. 2: in 2 Std 14 Min – Pizza")
  }

  @Test func linksReferencedMessageInList() {
    let list = reminderListText(
      for: [
        reminder(dueIn: 600, text: "Tee", number: 2, referencedMessageID: "9"),
        reminder(dueIn: 8_040, text: nil, number: 1, guildID: "3", referencedMessageID: "8"),
      ], now: now)
    #expect(
      list
        == "Deine Reminder:\nNr. 2: in 10 Min – Tee https://discord.com/channels/@me/1/9\n"
        + "Nr. 1: in 2 Std 14 Min – (ohne Text) https://discord.com/channels/3/1/8")
  }
}

private let snowflakes = Gen.int(in: 1...Int.max).map { String($0) }

@Suite struct ReferencedMessageURLTests {
  func reminder(channelID: String, guildID: String?, referencedMessageID: String?) -> Reminder {
    Reminder(
      userID: "42", channelID: channelID, messageID: "2", guildID: guildID,
      referencedMessageID: referencedMessageID, dueDate: Date(timeIntervalSince1970: 0), text: nil)
  }

  @Test func linksIntoGuild() async {
    await propertyCheck(input: snowflakes, snowflakes, snowflakes) { guild, channel, message in
      let url = reminder(channelID: channel, guildID: guild, referencedMessageID: message).referencedMessageURL
      #expect(url == "https://discord.com/channels/\(guild)/\(channel)/\(message)")
    }
  }

  @Test func linksIntoDirectMessages() async {
    await propertyCheck(input: snowflakes, snowflakes) { channel, message in
      let url = reminder(channelID: channel, guildID: nil, referencedMessageID: message).referencedMessageURL
      #expect(url == "https://discord.com/channels/@me/\(channel)/\(message)")
    }
  }

  @Test(arguments: ["3", nil] as [String?])
  func hasNoLinkWithoutReferencedMessage(guildID: String?) {
    #expect(reminder(channelID: "1", guildID: guildID, referencedMessageID: nil).referencedMessageURL == nil)
  }
}

@Suite struct ReminderRecipientsTests {
  func user(id: String, bot: Bool? = nil) throws -> DiscordUser {
    let botField = bot.map { #","bot":\#($0)"# } ?? ""
    let json = #"{"id":"\#(id)","username":"a","discriminator":"0"\#(botField)}"#
    return try JSONDecoder().decode(DiscordUser.self, from: Data(json.utf8))
  }

  @Test func isOnlyTheAuthorWithoutReactors() {
    #expect(reminderRecipients(authorID: "42", reactors: []) == ["42"])
  }

  @Test func listsAuthorFirstThenReactorsInOrder() throws {
    let reactors = try [user(id: "9"), user(id: "7", bot: false), user(id: "8")]
    #expect(reminderRecipients(authorID: "42", reactors: reactors) == ["42", "9", "7", "8"])
  }

  @Test func skipsBots() throws {
    let reactors = try [user(id: "1", bot: true), user(id: "7"), user(id: "2", bot: true)]
    #expect(reminderRecipients(authorID: "42", reactors: reactors) == ["42", "7"])
  }

  @Test func keepsAuthorFirstWhenAuthorReactedToo() throws {
    let reactors = try [user(id: "7"), user(id: "42")]
    #expect(reminderRecipients(authorID: "42", reactors: reactors) == ["42", "7"])
  }

  @Test func holdsForArbitraryReactors() async {
    // IDs above 4 stand for bots, so one account never appears as both bot and human.
    let isBot = { (id: Int) in id > 4 }
    await propertyCheck(input: Gen.int(in: 1...4), Gen.int(in: 1...6).array(of: 0...12)) { author, reactorIDs in
      let reactors = try reactorIDs.map { try user(id: String($0), bot: isBot($0)) }
      var expected = [String(author)]
      for id in reactorIDs where !isBot(id) && !expected.contains(String(id)) {
        expected.append(String(id))
      }
      #expect(reminderRecipients(authorID: String(author), reactors: reactors) == expected)
    }
  }

  @Test func deliveryMentionsAuthorAndHumanReactors() throws {
    let reactors = try [user(id: "1", bot: true), user(id: "42"), user(id: "7")]
    let reminder = Reminder(
      userID: "42", channelID: "1", messageID: "2", guildID: "3", dueDate: Date(timeIntervalSince1970: 0), text: nil)
    #expect(
      reminderDeliveryText(
        for: reminder, recipients: reminderRecipients(authorID: "42", reactors: reactors),
        now: Date(timeIntervalSince1970: 0)) == "⏰ <@42> <@7> Erinnerung!")
  }
}

@Suite struct ReminderStoreTests {
  let fileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("reminders-\(UUID().uuidString).json")

  func reminder(
    user: String = "42", dueIn seconds: Double, text: String? = nil, number: Int = 0,
    referencedMessageID: String? = nil
  ) -> Reminder {
    // Whole seconds, because the file stores ISO 8601 dates without fractions.
    let due = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 + seconds).rounded())
    return Reminder(
      number: number, userID: user, channelID: "1", messageID: "2", guildID: "3",
      referencedMessageID: referencedMessageID, dueDate: due, text: text)
  }

  func write(_ reminders: [Reminder], to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(reminders).write(to: url)
  }

  /// Fails a test waiting for a delivery that never comes. `.timeLimit` cannot do this: it cancels a sleep when the test
  /// ends, and Swift Testing segfaults capturing a backtrace of that throw on x86_64 Linux.
  func endAfterAMinute(_ continuation: AsyncStream<Reminder>.Continuation) {
    Task {
      try? await Task.sleep(for: .seconds(60))
      continuation.finish()
    }
  }

  func startedStore(at url: URL) async -> ReminderStore {
    let store = ReminderStore(fileURL: url)
    await store.start { _ in }
    return store
  }

  /// A file location whose parent directory doesn't exist yet, which makes writes fail without touching permissions.
  func urlInMissingDirectory() -> (directory: URL, file: URL) {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("reminders-\(UUID().uuidString)")
    return (directory, directory.appendingPathComponent("reminders.json"))
  }

  @Test func persistsAcrossInstances() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let first = await startedStore(at: fileURL)
    let saved = try await first.add(reminder(dueIn: 3_600, text: "Pizza"))

    let second = await startedStore(at: fileURL)
    #expect(await second.reminders(of: "42") == [saved])
  }

  @Test func persistsReferencedMessage() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let first = await startedStore(at: fileURL)
    try await first.add(reminder(dueIn: 3_600, referencedMessageID: "9"))

    let second = await startedStore(at: fileURL)
    let stored = await second.reminders(of: "42")
    #expect(stored.map(\.referencedMessageID) == ["9"])
    #expect(stored.map(\.referencedMessageURL) == ["https://discord.com/channels/3/1/9"])
  }

  @Test func limitsRemindersPerUser() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let store = await startedStore(at: fileURL)
    for index in 0..<ReminderStore.maxRemindersPerUser {
      try await store.add(reminder(dueIn: 3_600 + Double(index)))
    }
    await #expect(throws: ReminderStoreError.tooManyReminders) {
      try await store.add(reminder(dueIn: 3_600))
    }
    try await store.add(reminder(user: "other", dueIn: 3_600))
  }

  @Test func addReturnsTheReminderWithItsNumber() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let store = await startedStore(at: fileURL)
    var expected = reminder(dueIn: 3_600, text: "Pizza", referencedMessageID: "9")
    let stored = try await store.add(expected)
    expected.number = 1
    #expect(stored == expected)
    #expect(await store.reminders(of: "42") == [expected])
  }

  @Test func addIgnoresNumberOfIncomingReminder() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let store = await startedStore(at: fileURL)
    let stored = try await store.add(reminder(dueIn: 3_600, number: 4))
    #expect(stored.number == 1)
  }

  @Test func removesByNumberRegardlessOfDueOrder() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let store = await startedStore(at: fileURL)
    let later = try await store.add(reminder(dueIn: 7_200, text: "später"))
    let sooner = try await store.add(reminder(dueIn: 3_600, text: "früher"))
    #expect(later.number == 1)
    #expect(sooner.number == 2)
    #expect(await store.reminders(of: "42") == [sooner, later])

    #expect(try await store.remove(number: 3, of: "42") == nil)
    #expect(try await store.remove(number: 1, of: "other") == nil)
    #expect(try await store.remove(number: 1, of: "42") == later)
    #expect(await store.reminders(of: "42") == [sooner])
    #expect(try await store.remove(number: 1, of: "42") == nil)
  }

  @Test func reusesSmallestFreeNumber() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let store = await startedStore(at: fileURL)
    for index in 0..<4 {
      try await store.add(reminder(dueIn: 3_600 + Double(index)))
    }
    _ = try await store.remove(number: 3, of: "42")
    _ = try await store.remove(number: 1, of: "42")
    #expect(await store.reminders(of: "42").map(\.number) == [2, 4])

    #expect(try await store.add(reminder(dueIn: 7_200)).number == 1)
    #expect(try await store.add(reminder(dueIn: 7_200)).number == 3)
    #expect(try await store.add(reminder(dueIn: 7_200)).number == 5)
  }

  @Test func numbersBelongToEachUser() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let store = await startedStore(at: fileURL)
    let mine = try await store.add(reminder(dueIn: 3_600))
    let theirs = try await store.add(reminder(user: "other", dueIn: 3_600))
    #expect(mine.number == 1)
    #expect(theirs.number == 1)

    #expect(try await store.remove(number: 1, of: "other") == theirs)
    #expect(await store.reminders(of: "42") == [mine])
  }

  @Test func numbersSurviveRestart() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let first = await startedStore(at: fileURL)
    for index in 0..<3 {
      try await first.add(reminder(dueIn: 3_600 + Double(index)))
    }
    _ = try await first.remove(number: 2, of: "42")

    let second = await startedStore(at: fileURL)
    #expect(await second.reminders(of: "42").map(\.number) == [1, 3])
    #expect(try await second.add(reminder(dueIn: 3_600)).number == 2)
  }

  @Test func numbersStayWhenAnotherReminderIsDelivered() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let overdue = reminder(dueIn: -600, number: 2)
    let sooner = reminder(dueIn: 3_600, number: 3)
    let later = reminder(dueIn: 7_200, number: 1)
    try write([later, overdue, sooner], to: fileURL)

    let (deliveries, continuation) = AsyncStream<Reminder>.makeStream()
    endAfterAMinute(continuation)
    let store = ReminderStore(fileURL: fileURL)
    await store.start { continuation.yield($0) }
    var iterator = deliveries.makeAsyncIterator()
    let delivered = await iterator.next()
    #expect(delivered == overdue)

    #expect(await store.reminders(of: "42") == [sooner, later])
    #expect(try await store.add(reminder(dueIn: 3_600)).number == 2)
  }

  @Test func numbersFollowTheModelOverArbitraryOperations() async {
    let max = ReminderStore.maxRemindersPerUser
    let steps = zip(Gen.int(in: 0...2), Gen.int(in: 0...1), Gen.int(in: 0...(max + 2)), Gen.int(in: 0...86_400))
      .array(of: 1...40)
    await propertyCheck(input: steps) { steps in
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reminders-\(UUID().uuidString).json")
      defer { try? FileManager.default.removeItem(at: url) }
      let store = await startedStore(at: url)
      let users = ["42", "other"]
      var model: [String: [Int: Reminder]] = [:]

      func expectStoreMatchesModel(_ store: ReminderStore) async {
        for user in users {
          let listed = await store.reminders(of: user)
          let expected = (model[user] ?? [:]).values.sorted { $0.number < $1.number }
          #expect(listed.sorted { $0.number < $1.number } == expected)
          #expect(listed.map(\.dueDate) == listed.map(\.dueDate).sorted())
          #expect(listed.allSatisfy { (1...max).contains($0.number) })
        }
      }

      for (action, userIndex, number, due) in steps {
        let user = users[userIndex]
        let taken = model[user] ?? [:]
        if action == 0 {
          let removed = try await store.remove(number: number, of: user)
          #expect(removed == taken[number])
          model[user]?[number] = nil
        } else if taken.count == max {
          await #expect(throws: ReminderStoreError.tooManyReminders) {
            try await store.add(reminder(user: user, dueIn: 3_600 + Double(due)))
          }
        } else {
          let stored = try await store.add(reminder(user: user, dueIn: 3_600 + Double(due)))
          let smallestFree = (1...max).first { taken[$0] == nil }
          #expect(stored.number == smallestFree)
          model[user, default: [:]][stored.number] = stored
        }
        await expectStoreMatchesModel(store)
      }
      await expectStoreMatchesModel(await startedStore(at: url))
    }
  }

  @Test func deliversOverdueRemindersOnStart() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let overdue = reminder(dueIn: -600, text: "verpasst", number: 1)
    try write([overdue], to: fileURL)

    let store = ReminderStore(fileURL: fileURL)
    let delivered = await withCheckedContinuation { continuation in
      Task { await store.start { continuation.resume(returning: $0) } }
    }
    #expect(delivered == overdue)
    #expect(await store.reminders(of: "42").isEmpty)
  }

  @Test func failedSaveLeavesNoReminderPending() async {
    let (_, file) = urlInMissingDirectory()
    let store = await startedStore(at: file)

    // More attempts than the limit: failed reminders must not count towards it.
    for _ in 0...ReminderStore.maxRemindersPerUser {
      await #expect(throws: ReminderStoreError.saveFailed) {
        try await store.add(reminder(dueIn: 3_600))
      }
      #expect(await store.reminders(of: "42").isEmpty)
    }
  }

  @Test func failedReminderIsNeverDelivered() async throws {
    let (directory, file) = urlInMissingDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let (deliveries, continuation) = AsyncStream<Reminder>.makeStream()
    endAfterAMinute(continuation)
    let store = ReminderStore(fileURL: file)
    await store.start { continuation.yield($0) }

    await #expect(throws: ReminderStoreError.saveFailed) {
      try await store.add(reminder(dueIn: 1, text: "fehlgeschlagen"))
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let saved = try await store.add(reminder(dueIn: 2, text: "gespeichert"))
    #expect(saved.number == 1)

    // The failed reminder is due first, so it would arrive first if it were still scheduled.
    var iterator = deliveries.makeAsyncIterator()
    let delivered = await iterator.next()
    #expect(delivered == saved)
  }

  @Test func failedSaveKeepsEarlierReminders() async throws {
    let (directory, file) = urlInMissingDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = await startedStore(at: file)
    let kept = try await store.add(reminder(dueIn: 3_600))

    try FileManager.default.removeItem(at: directory)
    await #expect(throws: ReminderStoreError.saveFailed) {
      try await store.add(reminder(dueIn: 1_800))
    }
    #expect(await store.reminders(of: "42") == [kept])

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let next = try await store.add(reminder(dueIn: 7_200))
    #expect(next.number == 2)
    #expect(await startedStore(at: file).reminders(of: "42") == [kept, next])
  }

  @Test func deletedReminderIsNeverDelivered() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let (deliveries, continuation) = AsyncStream<Reminder>.makeStream()
    endAfterAMinute(continuation)
    let store = ReminderStore(fileURL: fileURL)
    await store.start { continuation.yield($0) }

    let deleted = try await store.add(reminder(dueIn: 1, text: "gelöscht"))
    let kept = try await store.add(reminder(dueIn: 2, text: "bleibt"))
    #expect(try await store.remove(number: deleted.number, of: "42") == deleted)

    // The deleted reminder is due first, so it would arrive first if it still fired.
    var iterator = deliveries.makeAsyncIterator()
    let delivered = await iterator.next()
    #expect(delivered == kept)
  }

  @Test func failedDeleteKeepsTheReminder() async throws {
    let (directory, file) = urlInMissingDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = await startedStore(at: file)
    let kept = try await store.add(reminder(dueIn: 3_600))

    try FileManager.default.removeItem(at: directory)
    await #expect(throws: ReminderStoreError.saveFailed) {
      try await store.remove(number: kept.number, of: "42")
    }
    #expect(await store.reminders(of: "42") == [kept])
  }

  @Test func leavesUnreadableFileUntouched() async throws {
    let corruptURL = fileURL.appendingPathExtension("corrupt")
    let marker = fileURL.appendingPathComponent("marker")
    defer {
      try? FileManager.default.removeItem(at: fileURL)
      try? FileManager.default.removeItem(at: corruptURL)
    }
    // A directory can't be read as a file, whoever runs the tests.
    try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
    try Data("inhalt".utf8).write(to: marker)

    let store = await startedStore(at: fileURL)
    #expect(await store.reminders(of: "42").isEmpty)
    await #expect(throws: ReminderStoreError.saveFailed) {
      try await store.add(reminder(dueIn: 3_600))
    }
    #expect(await store.reminders(of: "42").isEmpty)

    #expect(try String(contentsOf: marker, encoding: .utf8) == "inhalt")
    #expect(!FileManager.default.fileExists(atPath: corruptURL.path))
  }

  @Test func doesNotOverwriteAFileItCouldNotReadUntilNextStart() async throws {
    defer { try? FileManager.default.removeItem(at: fileURL) }
    try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
    let blocked = await startedStore(at: fileURL)

    // The file becomes readable later, but this store never saw its contents, so writing would lose them.
    try FileManager.default.removeItem(at: fileURL)
    let existing = reminder(dueIn: 3_600, text: "alt", number: 1)
    try write([existing], to: fileURL)
    let contents = try Data(contentsOf: fileURL)

    await #expect(throws: ReminderStoreError.saveFailed) {
      try await blocked.add(reminder(dueIn: 7_200))
    }
    #expect(await blocked.reminders(of: "42").isEmpty)
    #expect(try Data(contentsOf: fileURL) == contents)

    let restarted = await startedStore(at: fileURL)
    #expect(await restarted.reminders(of: "42") == [existing])
    #expect(try await restarted.add(reminder(dueIn: 7_200)).number == 2)
  }

  @Test(arguments: ["kaputt", #"{"unerwartet":1}"#])
  func movesCorruptFileAsideAndKeepsWorking(contents: String) async throws {
    let corruptURL = fileURL.appendingPathExtension("corrupt")
    defer {
      try? FileManager.default.removeItem(at: fileURL)
      try? FileManager.default.removeItem(at: corruptURL)
    }
    try Data(contents.utf8).write(to: fileURL)

    let store = await startedStore(at: fileURL)
    #expect(await store.reminders(of: "42").isEmpty)
    #expect(try String(contentsOf: corruptURL, encoding: .utf8) == contents)

    let saved = try await store.add(reminder(dueIn: 3_600))
    #expect(saved.number == 1)
    #expect(await startedStore(at: fileURL).reminders(of: "42") == [saved])
    #expect(try String(contentsOf: corruptURL, encoding: .utf8) == contents)
  }
}
