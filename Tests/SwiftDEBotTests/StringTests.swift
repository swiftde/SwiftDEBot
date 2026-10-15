import PropertyBased
import Testing

@testable import SwiftDEBot

private let wordGen = Gen.letterOrNumber.string(of: 1...12)
private let blankGen = Gen<Character?>
    .element(of: [" ", "\t", "\n"] as [Character])
    .compactMap { $0 }
    .string(of: 0...5)

/// Joins words with runs of 1 to 3 spaces, taken from `gaps` cyclically.
private func joined(_ words: [String], gaps: [Int]) -> String {
    words.enumerated().map { index, word in
        index == 0 ? word : String(repeating: " ", count: gaps[index % gaps.count]) + word
    }.joined()
}

private func nonWhitespace(_ text: String) -> String {
    String(text.filter { !$0.isWhitespace })
}

private func words(_ text: String) -> [String] {
    text.split(whereSeparator: \.isWhitespace).map(String.init)
}

/// The rules every chunking result must follow, whatever the input.
private func expectValidChunks(_ chunks: [String], of input: String, maxChars: Int) {
    for chunk in chunks {
        #expect(chunk.count <= maxChars, "chunk longer than \(maxChars): \(chunk.debugDescription)")
        #expect(chunk.contains { !$0.isWhitespace }, "empty or whitespace-only chunk in \(chunks)")
    }
    #expect(nonWhitespace(chunks.joined()) == nonWhitespace(input), "content lost or reordered")
}

@Suite struct MaxMessageLengthChunksTests {
    @Test func emptyInputYieldsNoChunks() {
        #expect("".maxMessageLengthChunks().isEmpty)
    }

    @Test func whitespaceOnlyInputYieldsNoChunks() async {
        #expect("   \n\t  ".maxMessageLengthChunks().isEmpty)
        await propertyCheck(input: blankGen, Gen.int(in: 1...50)) { blank, maxChars in
            #expect(blank.maxMessageLengthChunks(maxChars: maxChars).isEmpty)
        }
    }

    @Test func shortTextYieldsOneTrimmedChunk() {
        #expect("Hello world".maxMessageLengthChunks() == ["Hello world"])
        #expect("  Hello world \n".maxMessageLengthChunks() == ["Hello world"])
    }

    @Test func textOfExactlyMaxCharsYieldsOneChunk() {
        let text = String(repeating: "abcd ", count: 399) + "abcde"
        #expect(text.count == 2000)
        #expect(text.maxMessageLengthChunks() == [text])
        #expect("abc de".maxMessageLengthChunks(maxChars: 6) == ["abc de"])
    }

    @Test func defaultLimitIs2000Characters() {
        let text = String(repeating: "word ", count: 1000)
        let chunks = text.maxMessageLengthChunks()
        #expect(chunks.count > 1)
        expectValidChunks(chunks, of: text, maxChars: 2000)
    }

    @Test func splitsAtSpacesWithoutBreakingWords() {
        let text = "aaa bbb ccc ddd"
        let chunks = text.maxMessageLengthChunks(maxChars: 7)
        expectValidChunks(chunks, of: text, maxChars: 7)
        #expect(chunks.flatMap(words) == ["aaa", "bbb", "ccc", "ddd"])
    }

    @Test func fittingTextYieldsExactlyThatTextTrimmed() async {
        await propertyCheck(
            input: wordGen.array(of: 1...10),
            Gen.int(in: 1...3).array(of: 1...10),
            blankGen,
            blankGen
        ) { words, gaps, leading, trailing in
            let text = joined(words, gaps: gaps)
            let input = leading + text + trailing
            let chunks = input.maxMessageLengthChunks(maxChars: input.count)
            #expect(chunks == [text])
        }
    }

    @Test func chunksRespectLimitAndKeepEveryWordIntact() async {
        await propertyCheck(
            count: 500,
            input: Gen.int(in: 12...60),
            wordGen.array(of: 0...80),
            Gen.int(in: 1...3).array(of: 1...20)
        ) { maxChars, inputWords, gaps in
            let text = joined(inputWords, gaps: gaps)
            let chunks = text.maxMessageLengthChunks(maxChars: maxChars)
            expectValidChunks(chunks, of: text, maxChars: maxChars)
            // Each word fits within maxChars, so splitting the chunks at
            // whitespace must give back exactly the input words.
            #expect(chunks.flatMap(words) == inputWords)
        }
    }

    @Test func chunksRespectLimitForMultilineText() async {
        let separator = Gen<String?>
            .element(of: [" ", "  ", "\n", "\n\n", " \n "] as [String])
            .compactMap { $0 }
        await propertyCheck(
            count: 300,
            input: Gen.int(in: 12...60),
            wordGen.array(of: 0...80),
            separator.array(of: 80)
        ) { maxChars, inputWords, separators in
            let text = Swift.zip(inputWords, separators).map { $0 + $1 }.joined()
            let chunks = text.maxMessageLengthChunks(maxChars: maxChars)
            expectValidChunks(chunks, of: text, maxChars: maxChars)
        }
    }

    @Test func wordsLongerThanLimitStillRespectLimitAndLoseNothing() async {
        await propertyCheck(
            count: 300,
            input: Gen.int(in: 1...10),
            Gen.letterOrNumber.string(of: 1...40).array(of: 0...20),
            Gen.int(in: 1...3).array(of: 1...20)
        ) { maxChars, inputWords, gaps in
            let text = joined(inputWords, gaps: gaps)
            let chunks = text.maxMessageLengthChunks(maxChars: maxChars)
            expectValidChunks(chunks, of: text, maxChars: maxChars)
        }
    }

    @Test func singleOverlongWordIsSplitWithinLimit() {
        let text = String(repeating: "x", count: 4500)
        let chunks = text.maxMessageLengthChunks()
        expectValidChunks(chunks, of: text, maxChars: 2000)
    }
}
