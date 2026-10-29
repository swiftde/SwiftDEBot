import DiscordBM
import Foundation

struct UptimeCommand: MessageCommand {
  let helpText = "`!uptime`: Gibt aus wie lange ich schon seit dem letzten Neustart laufe."

  func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
    guard message.content.invocation(of: "!uptime") != nil else { return }
    let uptime = elapsedDescription(seconds: Int(Date().timeIntervalSince(startDate)))
    try await client.send("Uptime: \(uptime)", to: message.channel_id)
  }
}
