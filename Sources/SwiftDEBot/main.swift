import Foundation
import Sword

guard let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] else {
    fatalError("No token found in environment, please set DISCORD_TOKEN.")
}
let bot = Sword(token: token)

bot.editStatus(to: "", playing: "swiftc -Ounchecked")

func heartsMessage(to user: String) -> String {
    return """
    Hey @\(user), das korrekte Herz Emoji sieht so aus ❤️. Alternativ sind auch 💜, 💙, 💚, 💛, 🧡, 🖤, 🤍, 🤎, 💖, 💝, 💞, 💗, 💘, 💕 und 💓 zulässig. Kann allen mal passieren, dass man da aus Versehen das Falsche wählt. Du solltest wissen, dass diese Herz Emoji und das von dir getippte unterschiedliche Bedeutungen haben. Die genannten drücken aus, dass du etwas magst, toll findest, liebst oder auf sonstige Art deine Zuneigung ausdrücken willst. Das von dir getippte allerdings zeigt, dass du ein Monster bist ✌️
    """
}

bot.on(.messageCreate) { data in
    guard let message = data as? Message else { return }

    switch message.content {
    case "!ping":
        bot.send("pong", to: message.channel.id)
    case "!hallo":
        if let name = message.author?.username {
            bot.send("Hi \(name) :wave:", to: message.channel.id)
        } else {
            bot.send("Hi :wave:", to: message.channel.id)
        }
    case "♥️":
        bot.send(heartsMessage(to: message.author!.username!), to: message.channel.id)
    default:
        break
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
            bot.send(heartsMessage(to: username), to: channel.id)
        }
    default:
        break
    }
}

bot.connect()
