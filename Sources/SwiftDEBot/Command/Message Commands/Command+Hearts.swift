import Sword

extension Command where Trigger == Message {
    static func heartsMessage(to handle: String) -> String {
        return "Hey \(handle), es gibt eine ganze Reihe von Herz-Emoji: ❤️, 💜, 💙, 💚, 💛, 🧡, 🖤, 🤍, 🤎, 💖, 💝, 💞, 💗, 💘, 💕 und 💓. Das von dir genutzte ♥️ ist allerdings Teil des Sets von Symbolen für Spielkarten, zusammen mit ♠️, ♣️ und ♦️ und ist daher eher unpassend in anderen Kontexten."
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
