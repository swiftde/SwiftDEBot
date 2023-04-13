import DiscordBM

struct PingCommand: Command {
    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content == "!ping" else { return }
        try await client.addReaction(.unicodeEmoji("🏓"), to: message.id, in: message.channel_id)
    }
}
