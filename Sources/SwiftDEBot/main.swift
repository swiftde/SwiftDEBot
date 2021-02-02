import Foundation
import Sword

guard let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] else {
    fatalError("No token found in environment, please set DISCORD_TOKEN.")
}
let bot = Sword(token: token)
let messageCommands: [MessageCommand] = [
    .hello,
    .hearts,
    .ping
]

bot.editStatus(to: "", playing: "swiftc -Ounchecked")

bot.on(.messageCreate) { data in
    guard let message = data as? Message else { return }
    do {
        try messageCommands
            .filter { $0.shouldRun(message) }
            .forEach { command in
                try command.run(bot, message)
            }
    }
    catch {
        bot.send("Oops, das ging schief.", to: message.channel.id)
    }
}

bot.on(.reactionAdd) { data in
    guard let (channel, userID, messageID, emoji) = data as? (TextChannel, Snowflake, Snowflake, Emoji) else { return }

    switch emoji.name {
    case "this2":
        bot.addReaction("a:this:785804431597240351", to: messageID, in: channel.id)
    case "♥️":
        bot.getUser(userID) { user, _ in
            guard let username = user?.username else { return }
            bot.send(MessageCommand.heartsMessage(to: username), to: channel.id)
        }
    default:
        break
    }
}

bot.connect()
