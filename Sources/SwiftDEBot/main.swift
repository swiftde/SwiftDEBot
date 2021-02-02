import Foundation
import Sword

guard let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] else {
    fatalError("No token found in environment, please set DISCORD_TOKEN.")
}
let bot = Sword(token: token)
let commands: [Command] = [
    .hello,
    .hearts,
    .ping,
    .xcode,
    .heartsReaction,
    .this
]

bot.editStatus(to: "", playing: "swiftc -Ounchecked")

bot.on(.messageCreate) { data in
    guard
        let message = data as? Message,
        !(message.author?.isBot ?? false)
    else { return }

    do {
        try commands
            .filter { $0.shouldRun(onMessageCreate: message) }
            .forEach { command in
                try command.run(bot, onMessageCreate: message)
            }
    }
    catch {
        bot.send("Oops, das ging schief.", to: message.channel.id)
    }
}

bot.on(.reactionAdd) { data in
    guard let (channel, userID, messageID, emoji) = data as? (TextChannel, Snowflake, Snowflake, Emoji) else {
        return
    }

    let reaction = Reaction(
        channel: channel,
        userID: userID,
        messageID: messageID,
        emoji: emoji
    )

    do {
        try commands
            .filter { $0.shouldRun(onReactionAdd: reaction) }
            .forEach { command in
                try command.run(bot, onReactionAdd: reaction)
            }
    }
    catch {
        bot.send("Oops, das ging schief.", to: reaction.channel.id)
    }
}

bot.connect()
