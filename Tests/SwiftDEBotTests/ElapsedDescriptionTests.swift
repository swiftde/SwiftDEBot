import PropertyBased
import Testing

@testable import SwiftDEBot

private let minute = 60
private let hour = 60 * minute
private let day = 24 * hour

/// Durations spread across every field count, with extra weight just around
/// each boundary where an off-by-one would show.
private let durations = Gen.oneOf(
  Gen.int(in: 0...(2 * minute)),
  Gen.int(in: 0..<hour),
  Gen.int(in: (hour - 2 * minute)...(hour + 2 * minute)),
  Gen.int(in: hour..<day),
  Gen.int(in: (day - 2 * minute)...(day + 2 * minute)),
  Gen.int(in: day...(1000 * day)),
  Gen.int(in: 0...(10_000_000 * day))
)

/// Parses `[[DD-]HH:]MM:SS` strictly, so a malformed output fails to parse
/// rather than parsing to a wrong number: two-digit fields in range, hours
/// only once they are non-zero or days are shown, days without leading zeros.
private func parseElapsed(_ text: String) -> Int? {
  func twoDigits(_ field: Substring, below limit: Int) -> Int? {
    guard field.count == 2, field.allSatisfy(\.isASCII), field.allSatisfy(\.isNumber),
      let value = Int(field), value < limit
    else { return nil }
    return value
  }

  var days = 0
  var clock = Substring(text)
  let dayParts = text.split(separator: "-", omittingEmptySubsequences: false)
  if dayParts.count == 2 {
    let dayField = dayParts[0]
    guard !dayField.isEmpty, dayField.allSatisfy(\.isASCII), dayField.allSatisfy(\.isNumber),
      dayField.first != "0", let value = Int(dayField)
    else { return nil }
    days = value
    clock = dayParts[1]
  } else if dayParts.count != 1 {
    return nil
  }

  let fields = clock.split(separator: ":", omittingEmptySubsequences: false)
  let hasDays = dayParts.count == 2
  guard (hasDays && fields.count == 3) || (!hasDays && (fields.count == 2 || fields.count == 3))
  else { return nil }

  guard let seconds = twoDigits(fields[fields.count - 1], below: 60),
    let minutes = twoDigits(fields[fields.count - 2], below: 60)
  else { return nil }
  var hours = 0
  if fields.count == 3 {
    guard let value = twoDigits(fields[0], below: 24) else { return nil }
    // Without days, a zero hour field is never printed.
    if !hasDays && value == 0 { return nil }
    hours = value
  }
  return days * day + hours * hour + minutes * minute + seconds
}

/// Number of numeric fields in the output: 2 for MM:SS, 3 with hours, 4 with days.
private func fieldCount(_ text: String) -> Int {
  text.split(whereSeparator: { $0 == ":" || $0 == "-" }).count
}

private func expectedFieldCount(_ seconds: Int) -> Int {
  if seconds < hour { return 2 }
  if seconds < day { return 3 }
  return 4
}

/// Output order: a longer string is a longer duration, and strings of equal
/// length compare like the durations they describe.
private func precedes(_ lhs: String, _ rhs: String) -> Bool {
  lhs.count != rhs.count ? lhs.count < rhs.count : lhs < rhs
}

/// Typed up front: as an untyped literal inside `@Test(arguments:)`, the list
/// is too slow for the type checker.
private let etimeExamples: [(Int, String)] = [
  (0, "00:00"),
  (1, "00:01"),
  (5, "00:05"),
  (59, "00:59"),
  (60, "01:00"),
  (65, "01:05"),
  (599, "09:59"),
  (600, "10:00"),
  (3599, "59:59"),
  (3600, "01:00:00"),
  (3661, "01:01:01"),
  (36000, "10:00:00"),
  (86399, "23:59:59"),
  (86400, "1-00:00:00"),
  (90061, "1-01:01:01"),
  (9 * 86400 + 86399, "9-23:59:59"),
  (10 * 86400, "10-00:00:00"),
  (100 * 86400, "100-00:00:00"),
  (Int.max, "106751991167300-15:30:07"),
]

@Suite struct ElapsedDescriptionTests {
  @Test(arguments: etimeExamples)
  func formatsLikeProcpsEtime(seconds: Int, expected: String) {
    #expect(elapsedDescription(seconds: seconds) == expected)
  }

  @Test(arguments: [-1, -59, -3600, -86400, Int.min])
  func negativeInputIsTreatedAsZero(seconds: Int) {
    #expect(elapsedDescription(seconds: seconds) == "00:00")
  }

  @Test func anyNegativeInputIsTreatedAsZero() async {
    await propertyCheck(input: Gen.int(in: Int.min ... -1)) { seconds in
      #expect(elapsedDescription(seconds: seconds) == "00:00")
    }
  }

  @Test func parsingTheOutputYieldsTheInput() async {
    await propertyCheck(count: 1000, input: durations) { seconds in
      let text = elapsedDescription(seconds: seconds)
      #expect(parseElapsed(text) == seconds, "\(seconds) formatted as \(text.debugDescription)")
    }
  }

  @Test func fieldCountDependsOnlyOnMagnitude() async {
    await propertyCheck(count: 1000, input: durations) { seconds in
      let text = elapsedDescription(seconds: seconds)
      #expect(fieldCount(text) == expectedFieldCount(seconds), "\(seconds) formatted as \(text)")
    }
  }

  @Test func longerDurationsSortAfterShorterOnes() async {
    await propertyCheck(count: 1000, input: durations, durations) { a, b in
      guard a != b else { return }
      let (shorter, longer) = (min(a, b), max(a, b))
      let shorterText = elapsedDescription(seconds: shorter)
      let longerText = elapsedDescription(seconds: longer)
      #expect(
        precedes(shorterText, longerText),
        "\(shorter) → \(shorterText) should precede \(longer) → \(longerText)")
      #expect(fieldCount(shorterText) <= fieldCount(longerText))
    }
  }

  @Test func neighboringSecondsSortInOrder() async {
    await propertyCheck(count: 1000, input: durations) { seconds in
      let current = elapsedDescription(seconds: seconds)
      let next = elapsedDescription(seconds: seconds + 1)
      #expect(precedes(current, next), "\(current) should precede \(next)")
    }
  }
}
