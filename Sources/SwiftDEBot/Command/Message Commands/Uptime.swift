import DiscordBM
import Shell

struct UptimeCommand: MessageCommand {
    let helpText = "`!uptime`: Gibt aus wie lange ich schon (ohne Neustart) laufe."

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content == "!uptime" else { return }
        try await client.send(shell.uptime().stdout, to: message.channel_id)
    }
}
