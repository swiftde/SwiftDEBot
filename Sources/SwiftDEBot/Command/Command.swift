import Sword

struct Reaction {
    let channel: TextChannel
    let userID: Snowflake
    let messageID: Snowflake
    let emoji: Emoji
}

struct Command {
    enum Trigger {
        case messageCreate(Message)
        case reactionAdd(Reaction)
    }

    var shouldRun: (Trigger) -> Bool
    var run: (Sword, Trigger) throws -> Void
}
