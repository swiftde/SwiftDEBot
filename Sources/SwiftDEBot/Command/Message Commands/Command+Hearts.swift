import Sword

extension Command where Trigger == Message {
    static func heartsMessage(to handle: String) -> String {
        return """
        Hey \(handle), das korrekte Herz Emoji sieht so aus ❤️. Alternativ sind auch 💜, 💙, 💚, 💛, 🧡, 🖤, 🤍, 🤎, 💖, 💝, 💞, 💗, 💘, 💕 und 💓 zulässig. Kann allen mal passieren, dass man da aus Versehen das Falsche wählt. Du solltest wissen, dass diese Herz Emoji und das von dir getippte unterschiedliche Bedeutungen haben. Die genannten drücken aus, dass du etwas magst, toll findest, liebst oder auf sonstige Art deine Zuneigung ausdrücken willst. Das von dir getippte allerdings zeigt, dass du ein Monster bist ✌️
        """
    }

    static let hearts = Command(
        run: { bot, message in
            guard message.content.contains("♥️"),
                  let author = message.author, !(author.isBot ?? false) else {
                return
            }

            bot.send(
                heartsMessage(to: author.mentionHandle),
                to: message.channel.id
            )
        }
    )
}
