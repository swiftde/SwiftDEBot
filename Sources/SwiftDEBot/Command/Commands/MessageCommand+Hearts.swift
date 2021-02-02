extension MessageCommand {
    static func heartsMessage(to user: String) -> String {
        return """
        Hey @\(user), es gibt eine ganze Reihe von Herz-Emoji: ❤️, 💜, 💙, 💚, 💛, 🧡, 🖤, 🤍, 🤎, 💖, 💝, 💞, 💗, 💘, 💕 und 💓.
        Das von dir genutzte ♥️ ist allerdings Teil des Sets von Symbolen für Spielkarten, zusammen mit ♠️, ♣️ und ♦️ und ist daher
        eher unpassend in anderen Kontexten.
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
