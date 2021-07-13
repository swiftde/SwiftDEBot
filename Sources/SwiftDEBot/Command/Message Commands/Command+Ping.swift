import Sword

extension Command where Trigger == Message {
    static let ping = Command(
        run: { bot, message in
            guard message.content == "!ping" else { return }
            bot.addReaction(
                "🏓",
                to: message.id,
                in: message.channel.id
            )
        }
    )
}
