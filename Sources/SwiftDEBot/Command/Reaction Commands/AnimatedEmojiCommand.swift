import DiscordBM

struct AnimatedEmojiCommand: ReactionCommand {
    func run(client: DiscordClient, reaction: Gateway.MessageReactionAdd) async throws {
        let emojiDict: [String: Reaction] = [
            "this2": .guildEmoji(name: "this", id: "785804431597240351"),
            "jumprope2": .guildEmoji(name: "jumprope", id: "1441710287257604198"),
        ]
        
        for (name, reactionEmoji) in emojiDict where name == reaction.emoji.name {
            try await client.addReaction(reactionEmoji, to: reaction.message_id, in: reaction.channel_id)
        }
    }
}
