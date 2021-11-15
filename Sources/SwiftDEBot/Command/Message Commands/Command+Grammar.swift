import Sword

extension Command where Trigger == Message {
    fileprivate static let grammarOffenders = [
        "137444620631015424", // Veit
        "296369044775501824" // Fabian
    ]

    static let spaceBeforePunctuationMark = Command(
        run: { bot, message in
            guard
                let userID = message.author?.id,
                grammarOffenders.contains(String(describing: userID)),
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
