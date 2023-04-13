import DiscordBM

struct ThisCommand: ReactionCommand {
    func run(client: DiscordClient, reaction: Gateway.MessageReactionAdd) async throws {
        guard reaction.emoji.name == "this2" else { return }
        // "a:this:785804431597240351"
        try await client.addReaction(
            .guildEmoji(name: "this", id: "785804431597240351"), to: reaction.message_id, in: reaction.channel_id)
    }
}
