import DiscordBM

extension PartialUser {
    var mentionHandle: String {
        DiscordUtils.userMention(id: self.id)
    }
}
