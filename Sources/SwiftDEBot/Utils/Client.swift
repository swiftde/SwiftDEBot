import DiscordBM

extension DiscordClient {
  @discardableResult
  func send(_ message: String, to channelID: String) async throws -> DiscordClientResponse<DiscordChannel.Message> {
    try await self.createMessage(channelId: channelID, payload: .init(content: message))
  }

  /// Sends text written by a model. It may repeat mentions from the chat it was given, so it must not ping anyone. Link
  /// previews are hidden because a few cited sources would otherwise bury the answer.
  @discardableResult
  func sendModelOutput(_ message: String, to channelID: String) async throws
    -> DiscordClientResponse<DiscordChannel.Message>
  {
    try await self.createMessage(
      channelId: channelID,
      payload: .init(
        content: message,
        allowed_mentions: .init(parse: [], roles: [], users: [], replied_user: false),
        flags: [.suppressEmbeds]
      )
    )
  }

  @discardableResult
  func addReaction(_ emoji: Reaction, to messageID: String, in channelID: String) async throws -> DiscordHTTPResponse {
    try await self.addOwnMessageReaction(channelId: channelID, messageId: messageID, emoji: emoji)
  }

  @discardableResult
  func setTyping(in channelID: String) async throws -> DiscordHTTPResponse {
    try await self.triggerTypingIndicator(channelId: channelID)
  }

  /// Shows the typing indicator until `operation` finishes. Discord hides it after about 10 seconds, so it is renewed
  /// for operations that take longer.
  func whileTyping<Result>(in channelID: String, _ operation: () async throws -> Result) async rethrows -> Result {
    let typing = Task {
      while !Task.isCancelled {
        _ = try? await setTyping(in: channelID)
        try? await Task.sleep(for: .seconds(8))
      }
    }
    defer { typing.cancel() }
    return try await operation()
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
