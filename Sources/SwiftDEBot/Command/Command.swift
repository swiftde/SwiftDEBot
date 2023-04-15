import DiscordBM

protocol MessageCommand {
    var helpText: String { get }
    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws
}

protocol ReactionCommand {
    func run(client: DiscordClient, reaction: Gateway.MessageReactionAdd) async throws
}
