import Foundation

extension String {
  /// The first http or https URL in a message. Stops at `>` because Discord users wrap links in `<…>` to suppress
  /// their preview, and the brackets are not part of the URL.
  var firstURL: String? {
    firstMatch(of: #/https?://[^\s>]+/#).map { String($0.output) }
  }

  /// Splits text into non-empty messages within Discord's length limit, preferring to cut at whitespace so line
  /// breaks survive and words stay whole. Words longer than the limit are cut hard.
  func maxMessageLengthChunks(maxChars: Int = 2000) -> [String] {
    precondition(maxChars > 0, "maxChars must be positive")
    var chunks: [String] = []
    var rest = trimmingCharacters(in: .whitespacesAndNewlines)
    while !rest.isEmpty {
      // One character past the limit, so whitespace right after a full chunk still counts as a cut point.
      let window = rest.prefix(maxChars + 1)
      let cut =
        if window.count <= maxChars {
          rest.endIndex
        } else {
          // dropFirst guarantees progress even if the two whitespace definitions disagree.
          window.dropFirst().lastIndex(where: \.isWhitespace)
            ?? rest.index(rest.startIndex, offsetBy: maxChars)
        }
      chunks.append(rest[..<cut].trimmingCharacters(in: .whitespacesAndNewlines))
      rest = rest[cut...].trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return chunks
  }
}

extension CharacterSet {
  /// For a whole URL passed as one query value. `urlQueryAllowed` keeps `&`, `=` and `+`, which would split the
  /// value into further parameters or turn into a space on the server.
  static let queryValueAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+"))
}
