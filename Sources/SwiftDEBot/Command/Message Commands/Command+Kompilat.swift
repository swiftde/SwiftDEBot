import Sword

extension Command where Trigger == Message {
    static let kompilat = Command(
        run: { bot, message in
            guard message.content.lowercased().contains("kompilat") else { return }
            bot.addReaction(
                "🤢",
                to: message.id,
                in: message.channel.id
            )
        }
    )
}
