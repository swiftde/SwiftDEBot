import Sword

extension Command where Trigger == Message {
    fileprivate static let grammarOffenders = [
        "137444620631015424", // Veit
        "296369044775501824" // Fabian
    ]

    fileprivate static let reactions = [
        "⁉️",
        "🙄",
        "🤦",
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

            for reaction in reactions {
                bot.addReaction(reaction, to: message.id, in: message.channel.id)
            }
        }
    )
}
