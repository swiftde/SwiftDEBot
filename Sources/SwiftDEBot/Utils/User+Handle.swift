import Sword

extension User {
    /// Use this to mention the user, evaluates to `"<@!\(self.id)>"`. No need for additional @s.
    var mentionHandle: String {
        return "<@!\(self.id)>"
    }
}
