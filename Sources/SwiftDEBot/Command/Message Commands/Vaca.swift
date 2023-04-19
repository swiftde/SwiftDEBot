import DiscordBM
import cows

struct CowsCommand: MessageCommand {
    let helpText = "`!vaca` oder `!vaca <query>`: 🐄 moooooo."

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content.starts(with: "!vaca") else { return }

        let cow: String
        if let query = message.content.queryString {
            cow = cows.allCows.filter { $0.lowercased().contains(query) }.randomElement() ?? cows.vaca()
        } else {
            cow = cows.vaca()
        }

        try await client.send("""
        ```
        \(cow)
        ```
        """, to: message.channel_id)
    }
}
