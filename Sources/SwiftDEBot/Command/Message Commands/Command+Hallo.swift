import Sword

extension Command where Trigger == Message {
    static let hello = Command(
        run: { bot, message in
            guard message.content == "!hallo" else {
                return
            }

            if let handle = message.author?.mentionHandle {
                bot.send("Hi \(handle) :wave:", to: message.channel.id)
            } else {
                bot.send("Hi :wave:", to: message.channel.id)
            }
        }
    )
}
