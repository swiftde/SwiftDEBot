import Foundation
import Sword

guard let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] else {
    fatalError("No token found in environment, please set DISCORD_TOKEN.")
}
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
        bot.deleteReaction(":this2:784350423862870016", from: messageID, in: channel.id)
    }
}

bot.connect()
