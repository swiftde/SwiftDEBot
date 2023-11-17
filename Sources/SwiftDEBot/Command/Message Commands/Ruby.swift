import DiscordBM
import Foundation

struct RubyCommand: MessageCommand {
    let helpText = ""

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        let content = message.content.lowercased()
        guard content.contains("ruby") || content.contains("cocoapods") || content.contains("fastlane"),
            let handle = message.author?.mentionHandle
        else {
            return
        }
        try await client.addReaction(
            .guildEmoji(name: "fckrby", id: "1174327414470496276"), to: reaction.message_id, in: reaction.channel_id)
    }
}
