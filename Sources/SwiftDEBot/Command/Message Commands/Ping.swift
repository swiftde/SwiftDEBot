import DiscordBM

struct PingCommand: MessageCommand {
    let helpText = "`!ping`: Schau nach ob ich noch online bin."

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content.invocation(of: "!ping") != nil else { return }
        try await client.addReaction(.unicodeEmoji("🏓"), to: message.id, in: message.channel_id)
    }
}
