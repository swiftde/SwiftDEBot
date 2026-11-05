import Foundation

/// Seconds per duration unit, keyed by every spelling `parseLeadingDuration` accepts in lowercase.
private let unitSeconds: [String: Double] = {
  let units: [(spellings: [String], seconds: Double)] = [
    (["s", "sek", "sekunde", "sekunden"], 1),
    (["m", "min", "minute", "minuten"], 60),
    (["h", "std", "stunde", "stunden"], 3_600),
    (["d", "t", "tag", "tage"], 86_400),
  ]
  var table: [String: Double] = [:]
  for unit in units {
    for spelling in unit.spellings { table[spelling] = unit.seconds }
  }
  return table
}()

/// Reads a duration such as `2,5h`, `10 minuten` or `1h 30m` from the start of `text`. It reads as many number-unit
/// pairs as it can and returns their total with the remaining text, trimmed. A number needs a unit, and the unit must
/// be a whole word, so `10 Tee` and `5mal` are no durations. Decimals may use a comma or a point.
func parseLeadingDuration(_ text: String) -> (seconds: Double, rest: String)? {
  var index = text.startIndex
  var total: Double = 0
  var foundComponent = false

  func skipWhitespace(_ index: inout String.Index) {
    while index < text.endIndex, text[index].isWhitespace { index = text.index(after: index) }
  }

  func scan(_ index: inout String.Index, while predicate: (Character) -> Bool) -> Substring {
    let start = index
    while index < text.endIndex, predicate(text[index]) { index = text.index(after: index) }
    return text[start..<index]
  }

  while true {
    var cursor = index
    skipWhitespace(&cursor)

    let isDigit: (Character) -> Bool = { $0.isASCII && $0.isNumber }
    var number = String(scan(&cursor, while: isDigit))
    guard !number.isEmpty else { break }
    if cursor < text.endIndex, text[cursor] == "," || text[cursor] == "." {
      var afterSeparator = text.index(after: cursor)
      let fraction = scan(&afterSeparator, while: isDigit)
      if !fraction.isEmpty {
        number += "." + fraction
        cursor = afterSeparator
      }
    }

    skipWhitespace(&cursor)
    let unit = scan(&cursor, while: \.isLetter).lowercased()
    guard let seconds = unitSeconds[unit], let value = Double(number) else { break }

    total += value * seconds
    foundComponent = true
    index = cursor
  }

  guard foundComponent else { return nil }
  return (total, text[index...].trimmingCharacters(in: .whitespacesAndNewlines))
}

/// Describes a duration in German for people, such as `2 Std 14 Min` or `45 Sek`. It shows at most the two largest
/// non-zero units, and seconds only below ten minutes.
func germanDurationDescription(seconds: Int) -> String {
  let total = max(seconds, 0)
  let parts: [(value: Int, unit: String)] = [
    (total / 86_400, total / 86_400 == 1 ? "Tag" : "Tage"),
    (total % 86_400 / 3_600, "Std"),
    (total % 3_600 / 60, "Min"),
    (total < 600 ? total % 60 : 0, "Sek"),
  ]
  let shown = parts.drop { $0.value == 0 }.prefix(2).filter { $0.value > 0 }
  guard !shown.isEmpty else { return "0 Sek" }
  return shown.map { "\($0.value) \($0.unit)" }.joined(separator: " ")
}
