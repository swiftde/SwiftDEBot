import Sword

extension Command {
    static func onMessageCreate(
        shouldRun basedOn: @escaping (Message) -> Bool,
        run: @escaping (Sword, Message) throws -> Void
    ) -> Command {
        Command(
            shouldRun: { trigger in
                guard case let .messageCreate(message) = trigger else {
                    return false
                }
                return basedOn(message)
            }, run: { bot, trigger in
                guard case let .messageCreate(message) = trigger else {
                    return
                }
                try run(bot, message)
            }
        )
    }

    func shouldRun(onMessageCreate message: Message) -> Bool {
        shouldRun(.messageCreate(message))
    }

    func run(_ bot: Sword, onMessageCreate message: Message) throws -> Void {
        try run(bot, .messageCreate(message))
    }
}
