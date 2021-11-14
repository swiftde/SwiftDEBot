import Sword

extension Command where Trigger == Message {
    fileprivate static let grammarOffenders = ["Veit", "Fabian"]

    static let spaceBeforePunctuationMark = Command(
        run: { bot, message in
            guard
                let username = message.author?.username,
                grammarOffenders.contains(username),
                message.content.range(of: "\\s[!?.]+$", options: .regularExpression) != nil
            else {
                return
            }
            bot.send(
                "Ey \(message.author?.mentionHandle ?? "du Dulli"), vor ein Satzzeichen gehört kein Leerzeichen. Wir sind hier nicht bei den Wilden! *slap*",
                to: message.channel.id
            )
        }
    )
}
