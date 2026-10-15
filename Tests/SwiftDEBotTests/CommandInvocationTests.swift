import PropertyBased
import Testing

@testable import SwiftDEBot

private let whitespace = Gen<Character?>
    .element(of: [" ", "\t", "\n"] as [Character])
    .compactMap { $0 }
    .string(of: 1...3)

private let optionalWhitespace = Gen<Character?>
    .element(of: [" ", "\t", "\n"] as [Character])
    .compactMap { $0 }
    .string(of: 0...3)

private let commands = Gen.lowercaseLetter.string(of: 1...8).map { "!" + $0 }

/// Arguments without surrounding whitespace. Words may start with `!` and are
/// joined by arbitrary inner whitespace, which must survive unchanged.
private let arguments = zip(
    zip(Gen.bool, Gen.letterOrNumber.string(of: 1...6))
        .map { bang, word in bang ? "!" + word : word }
        .array(of: 1...4),
    whitespace.array(of: 3)
)
.map { words, separators in
    words.dropFirst().enumerated().reduce(words[0]) { result, next in
        result + separators[next.offset] + next.element
    }
}

private func randomlyCased(_ string: String, flips: [Bool]) -> String {
    String(
        string.enumerated().map { offset, character in
            offset < flips.count && flips[offset] ? Character(character.uppercased()) : character
        }
    )
}

struct CommandInvocationTests {
    @Test(
        arguments: [
            ("!ping", "!ping", nil),
            ("!ping ", "!ping", nil),
            ("  !ping\n", "!ping", nil),
            ("!se async", "!se", "async"),
            ("!se   async  ", "!se", "async"),
            ("\t!se\nasync await", "!se", "async await"),
            ("!vaca some query", "!vaca", "some query"),
            ("!vaca some  query\nwith lines", "!vaca", "some  query\nwith lines"),
            ("!se !important", "!se", "!important"),
            ("!se !se again", "!se", "!se again"),
            ("!se Async", "!se", "Async"),
        ] as [(String, String, String?)])
    func matchingMessages(message: String, command: String, argument: String?) {
        #expect(message.invocation(of: command) == CommandInvocation(argument: argument))
    }

    @Test(arguments: [
        ("!Ping", "!ping"),
        ("!PING", "!ping"),
        ("!pInG now", "!ping"),
        ("!Se async", "!se"),
    ])
    func commandWordIsCaseInsensitive(message: String, command: String) {
        #expect(message.invocation(of: command) != nil)
    }

    @Test func argumentKeepsOriginalCase() {
        #expect("!SE AsyncSequence".invocation(of: "!se") == CommandInvocation(argument: "AsyncSequence"))
    }

    @Test(arguments: [
        ("!search", "!se"),
        ("!sex", "!se"),
        ("!se2", "!se"),
        ("!search async", "!se"),
        ("!spider", "!spi"),
        ("!se.", "!se"),
        ("hello !ping", "!ping"),
        ("x!ping", "!ping"),
        ("ping", "!ping"),
        ("!pin", "!ping"),
        ("", "!ping"),
        ("   \n", "!ping"),
        ("!", "!ping"),
    ])
    func nonMatchingMessages(message: String, command: String) {
        #expect(message.invocation(of: command) == nil)
    }

    @Test func argumentIsTrimmedButInnerWhitespaceKept() async {
        await propertyCheck(
            count: 500,
            input: commands, optionalWhitespace, whitespace, arguments, optionalWhitespace
        ) { command, leading, separator, argument, trailing in
            let message = leading + command + separator + argument + trailing
            #expect(message.invocation(of: command) == CommandInvocation(argument: argument))
        }
    }

    @Test func commandWithOnlyWhitespaceHasNoArgument() async {
        await propertyCheck(
            count: 300,
            input: commands, optionalWhitespace, optionalWhitespace
        ) { command, leading, trailing in
            let message = leading + command + trailing
            #expect(message.invocation(of: command) == CommandInvocation(argument: nil))
        }
    }

    @Test func randomlyCasedCommandWordStillMatches() async {
        await propertyCheck(
            count: 300,
            input: commands, Gen.bool.array(of: 9), arguments
        ) { command, flips, argument in
            let message = randomlyCased(command, flips: flips) + " " + argument
            #expect(message.invocation(of: command) == CommandInvocation(argument: argument))
        }
    }

    @Test func longerWordStartingWithCommandDoesNotMatch() async {
        await propertyCheck(
            count: 500,
            input: commands, Gen.letterOrNumber.string(of: 1...5), optionalWhitespace, arguments
        ) { command, suffix, separator, rest in
            let message = command + suffix + separator + rest
            #expect(message.invocation(of: command) == nil)
        }
    }

    @Test func commandNotAtStartDoesNotMatch() async {
        await propertyCheck(
            count: 500,
            input: Gen.letterOrNumber.string(of: 1...6), optionalWhitespace, commands, arguments
        ) { prefix, separator, command, rest in
            let message = prefix + separator + command + " " + rest
            #expect(message.invocation(of: command) == nil)
        }
    }
}
