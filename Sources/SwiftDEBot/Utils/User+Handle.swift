import DiscordBM

extension PartialUser {
    var mentionHandle: String {
        "<@!\(self.id)>"
    }
}
