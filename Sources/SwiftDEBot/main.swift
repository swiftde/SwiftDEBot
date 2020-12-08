import Foundation
import Sword

let token = CommandLine.arguments[1]
let bot = Sword(token: token)

bot.editStatus(to: "", playing: "swiftc -Ounchecked")

bot.on(.messageCreate) { data in
    guard let message = data as? Message else { return }

    if message.content == "!hallo" {
        if let name = message.author?.username {
            bot.send("Hi \(name) :wave:", to: message.channel.id)
        } else {
            bot.send("Hi :wave:", to: message.channel.id)
        }
    }
}

bot.on(.reactionAdd) { data in
    // Second value is userID
    guard let (channel, _, messageID, emoji) = data as? (TextChannel, Snowflake, Snowflake, Emoji) else { return }

    if emoji.name == "this2" {
        bot.addReaction("a:this:785804431597240351", to: messageID, in: channel.id)
    }
}

bot.connect()
