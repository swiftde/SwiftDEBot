import Sword

extension Command where Trigger == Message {
    static let spaceBeforePunctuationMark = Command(
        run: { bot, message in
            guard message.content.range(of: "\\s[!?.]+$", options: .regularExpression) != nil else { return }
            bot.send(
                "Ey \(message.author?.mentionHandle ?? "du Dulli"), vor einem Satzzeichen gehört kein Leerzeichen. Wir sind hier nicht bei den Wilden! *slap*",
                to: message.channel.id
            )
        }
    )
}
