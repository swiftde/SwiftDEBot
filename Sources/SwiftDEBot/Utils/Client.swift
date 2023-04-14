import DiscordBM

extension DiscordClient {
    @discardableResult
    func send(_ message: String, to channelID: String) async throws -> DiscordClientResponse<DiscordChannel.Message> {
        try await self.createMessage(channelId: channelID, payload: .init(content: message))
    }

    @discardableResult
    func addReaction(_ emoji: Reaction, to messageID: String, in channelID: String) async throws -> DiscordHTTPResponse {
        try await self.addOwnMessageReaction(channelId: channelID, messageId: messageID, emoji: emoji)
    }

    @discardableResult
    func setTyping(in channelID: String) async throws -> DiscordHTTPResponse {
        try await self.triggerTypingIndicator(channelId: channelID)
    }

    func channelIdentifier(for channelID: String) async -> String? {
        guard let channel = try? await self.getChannel(id: channelID).decode() else { return nil }
        if channel.type == .dm {
            return "DM"
        }
        if let guildID = channel.guild_id, let guild = try? await self.getGuild(id: guildID).decode() {
            return "\(guild.name)/\(channel.name ?? "")"
        } else {
            return channel.name
        }
    }
}
