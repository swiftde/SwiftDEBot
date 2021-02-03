import Sword

extension Command where Trigger == Reaction {
    static let heartsReaction = Command(
        run: { bot, reaction in
            guard reaction.emoji.name == "♥️", reaction.userID != bot.user?.id else {
                return
            }

            bot.getUser(reaction.userID) { user, _ in
                guard let user = user, !(user.isBot ?? false) else {
                    return
                }

                bot.send(
                    Command<Message>.heartsMessage(to: user.mentionHandle),
                    to: reaction.channel.id
                )
            }
        }
    )
}
