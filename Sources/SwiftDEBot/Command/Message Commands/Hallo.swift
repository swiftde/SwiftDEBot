import DiscordBM

struct HalloCommand: Command {
    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content == "!hallo" else { return }
        if let handle = message.author?.mentionHandle {
            try await client.send("Hi \(handle) 👋", to: message.channel_id)
        } else {
            try await client.send("Hi 👋", to: message.channel_id)
        }
    }
}
