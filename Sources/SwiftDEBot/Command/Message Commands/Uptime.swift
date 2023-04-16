import DiscordBM
import Shell

struct UptimeCommand: MessageCommand {
    let helpText = "`!uptime`: Gibt aus wie lange ich schon (ohne Neustart) laufe."

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content == "!uptime" else { return }
        let containerUptime = shell.ps("-o etime= -p 1").stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        try await client.send("Uptime: \(containerUptime)", to: message.channel_id)
    }
}
