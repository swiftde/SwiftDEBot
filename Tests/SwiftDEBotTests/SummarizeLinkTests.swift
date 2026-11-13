import Foundation
import PropertyBased
import Testing

@testable import SwiftDEBot

private let whitespace = Gen<Character?>
  .element(of: [" ", "\t", "\n"] as [Character])
  .compactMap { $0 }
  .string(of: 1...3)

private let words = Gen.letterOrNumber.string(of: 1...8).array(of: 0...4)

private let urlCharacter = Gen<Character?>
  .element(of: Array("abcXYZ019-_.~?=&%#:/@+"))
  .compactMap { $0 }

private let urls = zip(
  Gen.bool,
  Gen.lowercaseLetter.string(of: 1...10).array(of: 2...3),
  urlCharacter.string(of: 0...20)
)
.map { secure, labels, path in
  (secure ? "https" : "http") + "://" + labels.joined(separator: ".") + "/" + path
}

/// Joins tokens with the separators, taken cyclically.
private func joined(_ tokens: [String], separators: [String]) -> String {
  tokens.enumerated().map { index, token in
    index == 0 ? token : separators[index % separators.count] + token
  }.joined()
}

struct SummarizeLinkTests {
  @Test func returnsFirstURLWithoutEmbedSuppressingBrackets() async {
    await propertyCheck(
      count: 300,
      input: words, urls, Gen.bool, words, zip(Gen.bool, urls), whitespace.array(of: 1...4)
    ) { before, url, wrapped, after, second, separators in
      let (hasSecond, secondURL) = second
      let tokens =
        before + [wrapped ? "<\(url)>" : url] + after + (hasSecond ? [secondURL] : [])
      let message = joined(tokens, separators: separators)
      #expect(message.firstURL == url)
    }
  }

  @Test func encodedLinkSurvivesAsOneQueryValue() async {
    await propertyCheck(input: urls) { url in
      let encoded = try #require(url.addingPercentEncoding(withAllowedCharacters: .queryValueAllowed))
      let components = URLComponents(string: "https://kagi.com/api?target_language=DE&url=\(encoded)")
      #expect(components?.queryItems?.last == URLQueryItem(name: "url", value: url))
      // Servers commonly decode a literal + in a query as a space.
      #expect(!encoded.contains("+"))
    }
  }
}
