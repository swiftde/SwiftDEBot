import Sword

extension Command where Trigger == Message {
    static let spaceBeforePunctuationMark = Command(
        run: { bot, message in
            guard message.content.lowercased().contains(" ?") || message.content.contains(" !") else { return }
            bot.addReaction(
                "Ey \(message.author?.mentionHandle ?? "du Dulli"), vor einem Satzzeichen gehört kein Leerzeichen. Wir sind hier nicht bei den Wilden! *slap*",
                to: message.id,
                in: message.channel.id
            )
        }
    )
}
