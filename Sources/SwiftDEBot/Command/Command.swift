import DiscordBM

protocol MessageCommand: Sendable {
    var helpText: String { get }
    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws
}

protocol ReactionCommand: Sendable {
    func run(client: DiscordClient, reaction: Gateway.MessageReactionAdd) async throws
}
