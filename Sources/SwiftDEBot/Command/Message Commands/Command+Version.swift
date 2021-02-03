import Sword

extension Command where Trigger == Message {
    static let version = Command(
        run: { bot, message in
            guard message.content == "!version" else { return }
            bot.send("🤖 \(VERSION)", to: message.channel.id)
        }
    )
}
