extension Command {
    static let heartsReaction = Command.onReactionAdd(
        shouldRun: { reaction in reaction.emoji.name == "♥️" },
        run: { bot, reaction in
            guard reaction.userID != bot.user?.id else {
                return
            }

            bot.getUser(reaction.userID) { user, _ in
                guard let user = user, !(user.isBot ?? false) else {
                    return
                }

                bot.send(
                    Command.heartsMessage(to: user.mentionHandle),
                    to: reaction.channel.id
                )
            }
        }
    )
}
