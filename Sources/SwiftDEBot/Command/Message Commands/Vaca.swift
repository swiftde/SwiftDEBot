import DiscordBM
import Foundation
import cows

struct CowsCommand: MessageCommand {
    let helpText = "`!vaca` oder `!vaca <query>`: 🐄 moooooo."

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard let invocation = message.content.invocation(of: "!vaca") else { return }

        // Not cows.vaca(): it draws from shared mutable state that concurrent commands would race on.
        let matchingCows = cows.allCows.filter { cow in
            invocation.argument.map(cow.localizedCaseInsensitiveContains) ?? true
        }
        let cow = (matchingCows.isEmpty ? cows.allCows : matchingCows).randomElement() ?? ""

        try await client.send(
            """
            ```
            \(cow)
            ```
            """, to: message.channel_id)
    }
}
