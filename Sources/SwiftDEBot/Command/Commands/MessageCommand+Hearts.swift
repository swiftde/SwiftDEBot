extension MessageCommand {
    static func heartsMessage(to user: String) -> String {
        return """
        Hey @\(user), das korrekte Herz Emoji sieht so aus ❤️. Alternativ sind auch 💜, 💙, 💚, 💛, 🧡, 🖤, 🤍, 🤎, 💖, 💝, 💞, 💗, 💘, 💕 und 💓 zulässig. Kann allen mal passieren, dass man da aus Versehen das Falsche wählt. Du solltest wissen, dass diese Herz Emoji und das von dir getippte unterschiedliche Bedeutungen haben. Die genannten drücken aus, dass du etwas magst, toll findest, liebst oder auf sonstige Art deine Zuneigung ausdrücken willst. Das von dir getippte allerdings zeigt, dass du ein Monster bist ✌️
        """
    }

    static let hearts = MessageCommand(
        shouldRun: { message in message.content.contains("♥️") },
        run: { bot, message in
            guard let author = message.author?.username else {
                return
            }
            
            bot.send(heartsMessage(to: author), to: message.channel.id)
        }
    )
}
