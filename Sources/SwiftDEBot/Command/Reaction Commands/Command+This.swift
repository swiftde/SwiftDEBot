extension Command {
    static let this = Command.onReactionAdd(
        shouldRun: { reaction in reaction.emoji.name == "this2" },
        run: { bot, reaction in
            bot.addReaction(
                "a:this:785804431597240351",
                to: reaction.messageID,
                in: reaction.channel.id
            )
        }
    )
}
