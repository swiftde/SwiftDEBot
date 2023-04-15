import DiscordBM

struct VersionCommand: MessageCommand {
    let helpText = "`!version`: Gibt aus welche Version von mir hier gerade läuft."

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content == "!version" else { return }
        try await client.send(PackageBuild.info.describe, to: message.channel_id)
    }
}
