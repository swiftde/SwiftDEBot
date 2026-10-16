import Foundation
import PropertyBased
import Testing

@testable import SwiftDEBot

/// Builds a proposal entry as found in evolution.json, including keys the bot ignores.
private func entryJSON(
  id: String = "SE-0558",
  title: String = "Bulk update operations for `MutableSpan` and `MutableRawSpan`",
  authors: [String] = ["Guillaume Lessard"],
  status: [String: String] = ["state": "implemented", "version": "5.9"]
) -> [String: Any] {
  [
    "authors": authors.map { ["link": "https://github.com/someone", "name": $0] },
    "discussions": [["link": "https://forums.swift.org/t/89843", "name": "pitch"]],
    "id": id,
    "implementation": [
      ["account": "swiftlang", "id": "92466", "repository": "swift", "type": "pull"]
    ],
    "link": "0558-mutablespan-bulk-updates.md",
    "previousProposalIDs": ["SE-0467"],
    "reviewManagers": [["link": "https://github.com/jckarter", "name": "Joe Groff"]],
    "sha": "bc7b950d534cab0f12445d377665b55c456b4f6c",
    "status": status,
    "summary": "Adds bulk update operations ...",
    "title": title,
  ]
}

private func decode(_ entries: [[String: Any]]) throws -> EvolutionMetadata {
  let root: [String: Any] = [
    "commit": "bc7b950d534cab0f12445d377665b55c456b4f6c",
    "creationDate": "2026-10-16T08:00:00Z",
    "implementationVersions": ["5.9", "6.0"],
    "proposals": entries,
    "schemaVersion": "1.0.0",
    "toolVersion": "1.0.0",
  ]
  let data = try JSONSerialization.data(withJSONObject: root)
  return try JSONDecoder().decode(EvolutionMetadata.self, from: data)
}

private func makeProposal(
  id: String = "SE-0558",
  title: String = "Bulk update operations for `MutableSpan` and `MutableRawSpan`",
  authors: [String] = ["Guillaume Lessard"],
  status: [String: String] = ["state": "implemented", "version": "5.9"]
) throws -> Proposal {
  try #require(
    decode([entryJSON(id: id, title: title, authors: authors, status: status)]).proposals.first)
}

private func statusLine(_ status: [String: String]) throws -> String {
  let lines = try makeProposal(status: status).shortDescription.split(
    separator: "\n", omittingEmptySubsequences: false)
  try #require(lines.count == 4)
  return String(lines[2])
}

@Suite struct EvolutionMetadataDecodingTests {
  @Test func decodesProposalsFromTopLevelObject() throws {
    let metadata = try decode([
      entryJSON(id: "SE-0001", title: "First"),
      entryJSON(id: "SE-0558", title: "Second", status: ["state": "activeReview"]),
    ])
    #expect(metadata.proposals.map(\.id) == ["SE-0001", "SE-0558"])
    #expect(metadata.proposals.map(\.title) == ["First", "Second"])
  }

  @Test func decodesProposalWithOnlyState() throws {
    var entry = entryJSON(status: ["state": "withdrawn"])
    entry["previousProposalIDs"] = nil
    entry["implementation"] = nil
    #expect(try decode([entry]).proposals.count == 1)
  }

  @Test func decodesEmptyProposalList() throws {
    #expect(try decode([]).proposals.isEmpty)
  }
}

@Suite struct ProposalShortDescriptionTests {
  @Test func fullDescriptionForActiveReview() throws {
    let proposal = try makeProposal(status: [
      "end": "2026-10-28T00:00:00Z", "start": "2026-10-13T00:00:00Z", "state": "activeReview",
    ])
    #expect(
      proposal.shortDescription == """
        **SE-0558** Bulk update operations for `MutableSpan` and `MutableRawSpan`
        Autor(en): Guillaume Lessard
        Status: activeReview 13.10.26-28.10.26
        <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0558-mutablespan-bulk-updates.md>
        """
    )
  }

  @Test func versionIsShownWithSwiftPrefix() throws {
    #expect(try statusLine(["state": "implemented", "version": "5.9"]) == "Status: implemented Swift 5.9")
  }

  @Test func emptyVersionIsOmitted() throws {
    #expect(try statusLine(["state": "implemented", "version": ""]) == "Status: implemented")
  }

  @Test(arguments: [
    "implemented", "activeReview", "accepted", "rejected", "returnedForRevision", "withdrawn",
    "previewing",
  ])
  func onlyStateIsShownAsIs(state: String) throws {
    #expect(try statusLine(["state": state]) == "Status: \(state)")
  }

  @Test func datesAreFormattedInBerlinTime() throws {
    // Both instants are already the next day in Berlin, on either side of the DST switch.
    let line = try statusLine([
      "start": "2026-10-12T23:30:00Z", "end": "2026-10-27T23:30:00Z", "state": "activeReview",
    ])
    #expect(line == "Status: activeReview 13.10.26-28.10.26")
  }

  @Test func unparseableDatesFallBackToState() throws {
    let line = try statusLine(["start": "soon", "end": "later", "state": "activeReview"])
    #expect(line == "Status: activeReview")
  }

  @Test func multipleAuthorsAreCommaSeparated() throws {
    let description = try makeProposal(authors: ["Anna", "Bob", "Carl"]).shortDescription
    #expect(description.split(separator: "\n")[1] == "Autor(en): Anna, Bob, Carl")
  }

  @Test func titleIsTrimmed() throws {
    let description = try makeProposal(title: "  \n Padded title \n").shortDescription
    #expect(description.split(separator: "\n")[0] == "**SE-0558** Padded title")
  }
}

private let ids = Gen.int(in: 1...9999).map { "SE-" + String(format: "%04d", $0) }
private let titles = Gen.letterOrNumber.string(of: 1...20)

private func randomlyCased(_ string: String, flips: [Bool]) -> String {
  String(
    string.enumerated().map { offset, character in
      offset < flips.count && flips[offset]
        ? Character(character.uppercased()) : Character(character.lowercased())
    }
  )
}

private func substring(of string: String, from start: Int, length: Int) -> String {
  let offset = start % string.count
  let count = 1 + length % (string.count - offset)
  return String(string.dropFirst(offset).prefix(count))
}

@Suite struct ProposalMatchesTests {
  @Test(arguments: [
    ("SE-0558", true), ("se-0558", true), ("0558", true), ("mutablespan", true),
    ("BULK UPDATE", true), ("SE-0559", false), ("async", false),
  ])
  func examples(query: String, expected: Bool) throws {
    #expect(try makeProposal().matches(query: query) == expected)
  }

  @Test func anyCasingOfASubstringOfIdOrTitleMatches() async {
    await propertyCheck(
      input: ids, titles, Gen.bool, Gen.int(in: 0...100), Gen.int(in: 0...100),
      Gen.bool.array(of: 20)
    ) { id, title, useTitle, start, length, flips in
      let proposal = try makeProposal(id: id, title: title)
      let query = randomlyCased(
        substring(of: useTitle ? title : id, from: start, length: length), flips: flips)
      #expect(proposal.matches(query: query), "\(query) should match \(id) \(title)")
    }
  }

  @Test func queryWithForeignCharacterNeverMatches() async {
    await propertyCheck(input: ids, titles, titles) { id, title, word in
      let proposal = try makeProposal(id: id, title: title)
      #expect(!proposal.matches(query: word + "#"))
    }
  }
}
