import DiscordBM

protocol MessageCommand {
    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws
}

protocol ReactionCommand {
    func run(client: DiscordClient, reaction: Gateway.MessageReactionAdd) async throws
}
