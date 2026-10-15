import DiscordBM

struct HelpCommand: MessageCommand {
  let helpText = "`!hilfe` oder `!help`: Gibt diesen Text aus."

  func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
    guard ["!help", "!hilfe"].contains(where: { message.content.invocation(of: $0) != nil }) else { return }
    let commandHelp =
      messageCommands
      .map(\.helpText)
      .filter { !$0.isEmpty }
      .map { " - \($0)\n" }
      .joined()
    try await client.send(
      "Hi, ich bin Schwifty. Ich kenne folgende Befehle:\n" + commandHelp, to: message.channel_id)
  }
}
