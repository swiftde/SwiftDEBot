import DiscordBM
import cows

struct CowsCommand: MessageCommand {
    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content.starts(with: "!vaca") else { return }

        let components = message.content.components(separatedBy: " ")
        let cow: String
        if components.count > 1 {
            let query = components
                .dropFirst()
                .joined(separator: " ")
                .lowercased()
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
