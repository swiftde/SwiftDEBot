import DiscordBM
import Foundation

protocol MessageCommand: Sendable {
    var helpText: String { get }
    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws
}

protocol ReactionCommand: Sendable {
    func run(client: DiscordClient, reaction: Gateway.MessageReactionAdd) async throws
}

/// A message addressed to a command, such as `!se async`.
struct CommandInvocation: Equatable {
    /// The text after the command word, trimmed; nil if there is none.
    let argument: String?
}

extension String {
    /// Returns an invocation if this message starts with `command` as a whole word. Case is ignored because phone
    /// keyboards capitalize the first letter.
    func invocation(of command: String) -> CommandInvocation? {
        let message = trimmingCharacters(in: .whitespacesAndNewlines)
        let word = message.prefix { !$0.isWhitespace }
        guard word.caseInsensitiveCompare(command) == .orderedSame else { return nil }
        let argument = message[word.endIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
        return CommandInvocation(argument: argument.isEmpty ? nil : argument)
    }
}
