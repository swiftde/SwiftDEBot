import PropertyBased
import Testing

@testable import SwiftDEBot

private typealias ChatLine = FactCheckCommand.ChatLine

private let padding = Gen<Character?>
  .element(of: [" ", "\t", "\n"] as [Character])
  .compactMap { $0 }
  .string(of: 0...3)

/// Content without surrounding whitespace. Words are joined by inner whitespace,
/// including line breaks, which must survive unchanged.
private let content = zip(
  Gen.letterOrNumber.string(of: 1...6).array(of: 1...4),
  Gen<String?>
    .element(of: [" ", "  ", "\n", " \n "] as [String])
    .compactMap { $0 }
    .array(of: 3)
)
.map { words, separators in
  words.dropFirst().enumerated().reduce(words[0]) { result, next in
    result + separators[next.offset] + next.element
  }
}

private let authors = Gen<String?>
  .element(of: ["anna", "Bob", "kilian.io", "Max Mustermann", "ü_ber", "42"] as [String])
  .compactMap { $0 }

private let lines = zip(authors, content).map { ChatLine(author: $0, content: $1) }

private let paddedLines = zip(authors, padding, content, padding).map {
  author, leading, content, trailing in
  (
    padded: ChatLine(author: author, content: leading + content + trailing),
    trimmed: ChatLine(author: author, content: content)
  )
}

private func entry(_ line: ChatLine) -> String {
  "\(line.author): \(line.content)"
}

private typealias Transcript = FactCheckCommand.Transcript

private func targetSection(_ target: ChatLine) -> String {
  "Zu prüfende Nachricht:\n" + entry(target)
}

struct FactCheckTranscriptTests {
  @Test func contextIsListedOldestFirst() {
    let target = ChatLine(author: "carl", content: "Das stimmt so nicht.")
    let context = [
      ChatLine(author: "bob", content: "Neueste"),
      ChatLine(author: "anna", content: "Mittlere"),
      ChatLine(author: "carl", content: "Älteste"),
    ]
    #expect(
      FactCheckCommand.transcript(target: target, context: context, hint: nil)
        == Transcript(
          history: "Verlauf:\ncarl: Älteste\nanna: Mittlere\nbob: Neueste",
          target: "Zu prüfende Nachricht:\ncarl: Das stimmt so nicht.",
          hint: nil
        )
    )
  }

  @Test func onlyBlankContextYieldsNoHistory() {
    let target = ChatLine(author: "anna", content: "Behauptung")
    let context = [ChatLine(author: "bob", content: " \n "), ChatLine(author: "carl", content: "")]
    #expect(
      FactCheckCommand.transcript(target: target, context: context, hint: nil)
        == Transcript(history: nil, target: "Zu prüfende Nachricht:\nanna: Behauptung", hint: nil)
    )
  }

  @Test func contentIsTrimmedButKeepsInnerLineBreaks() {
    let target = ChatLine(author: "anna", content: "\n  Erste Zeile\n\nzweite  Zeile \n")
    let context = [ChatLine(author: "bob", content: "\tA\nB ")]
    #expect(
      FactCheckCommand.transcript(target: target, context: context, hint: nil)
        == Transcript(
          history: "Verlauf:\nbob: A\nB",
          target: "Zu prüfende Nachricht:\nanna: Erste Zeile\n\nzweite  Zeile",
          hint: nil
        )
    )
  }

  @Test func matchesTheDocumentedFormat() async {
    await propertyCheck(input: lines, lines.array(of: 0...10)) { target, context in
      let entries = context.reversed().map(entry)
      let expected = Transcript(
        history: entries.isEmpty ? nil : "Verlauf:\n" + entries.joined(separator: "\n"),
        target: targetSection(target),
        hint: nil
      )
      #expect(FactCheckCommand.transcript(target: target, context: context, hint: nil) == expected)
    }
  }

  @Test func surroundingWhitespaceDoesNotChangeTheResult() async {
    await propertyCheck(input: paddedLines, paddedLines.array(of: 0...10)) { target, context in
      #expect(
        FactCheckCommand.transcript(target: target.padded, context: context.map(\.padded), hint: nil)
          == FactCheckCommand.transcript(target: target.trimmed, context: context.map(\.trimmed), hint: nil)
      )
    }
  }

  @Test func blankContextMessagesDoNotChangeTheResult() async {
    await propertyCheck(
      input: lines,
      zip(Gen.bool, lines, authors, padding).map { isBlank, line, author, blank in
        (line: line, isBlank: isBlank, blankLine: ChatLine(author: author, content: blank))
      }.array(of: 0...10)
    ) { target, mixed in
      let withBlanks = mixed.map { $0.isBlank ? $0.blankLine : $0.line }
      let withoutBlanks = mixed.filter { !$0.isBlank }.map(\.line)
      #expect(
        FactCheckCommand.transcript(target: target, context: withBlanks, hint: nil)
          == FactCheckCommand.transcript(target: target, context: withoutBlanks, hint: nil)
      )
    }
  }

  @Test func hintIsAttributedToTheRequester() {
    let target = ChatLine(author: "anna", content: "Behauptung")
    let context = [ChatLine(author: "kilian", content: "Ich meinte Berlin.")]
    let hint = ChatLine(author: "kilian", content: "  Bitte nur die Zahl prüfen,\n\nsiehe  meine Nachricht \n")
    #expect(
      FactCheckCommand.transcript(target: target, context: context, hint: hint)
        == Transcript(
          history: "Verlauf:\nkilian: Ich meinte Berlin.",
          target: "Zu prüfende Nachricht:\nanna: Behauptung",
          hint: "Hinweis von kilian:\nBitte nur die Zahl prüfen,\n\nsiehe  meine Nachricht"
        )
    )
  }

  @Test func hintMatchesTheDocumentedFormat() async {
    await propertyCheck(input: lines, lines.array(of: 0...10), paddedLines) { target, context, hint in
      let result = FactCheckCommand.transcript(target: target, context: context, hint: hint.padded)
      #expect(result.hint == "Hinweis von \(hint.trimmed.author):\n\(hint.trimmed.content)")
    }
  }

  @Test func hintDoesNotChangeHistoryOrTarget() async {
    await propertyCheck(input: lines, lines.array(of: 0...10), lines) { target, context, hint in
      let withHint = FactCheckCommand.transcript(target: target, context: context, hint: hint)
      let withoutHint = FactCheckCommand.transcript(target: target, context: context, hint: nil)
      #expect(withHint.history == withoutHint.history)
      #expect(withHint.target == withoutHint.target)
    }
  }

  @Test func blankHintIsLikeNoHint() async {
    await propertyCheck(input: lines, lines.array(of: 0...10), authors, padding) {
      target, context, author, blank in
      #expect(
        FactCheckCommand.transcript(
          target: target, context: context, hint: ChatLine(author: author, content: blank))
          == FactCheckCommand.transcript(target: target, context: context, hint: nil)
      )
    }
  }
}
