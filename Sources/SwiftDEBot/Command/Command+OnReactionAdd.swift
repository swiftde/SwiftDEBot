import Sword

extension Command {
    static func onReactionAdd(
        shouldRun basedOn: @escaping (Reaction) -> Bool,
        run: @escaping (Sword, Reaction) throws -> Void
    ) -> Command {
        Command(
            shouldRun: { trigger in
                guard case let .reactionAdd(reaction) = trigger else {
                    return false
                }
                return basedOn(reaction)
            }, run: { bot, trigger in
                guard case let .reactionAdd(reaction) = trigger else {
                    return
                }
                try run(bot, reaction)
            }
        )
    }

    func shouldRun(onReactionAdd reaction: Reaction) -> Bool {
        shouldRun(.reactionAdd(reaction))
    }

    func run(_ bot: Sword, onReactionAdd reaction: Reaction) throws -> Void {
        try run(bot, .reactionAdd(reaction))
    }
}
