import Sword

extension Sword {
    func onMessageCreate(_ do: @escaping (Sword, Message) -> Void) {
        on(.messageCreate) { data in
            guard let message = data as? Message, !(message.author?.isBot ?? false) else {
                return
            }

            `do`(self, message)
        }
    }

    func onMessageCreate(_ commands: Command<Message>...) {
        for command in commands {
            onMessageCreate(command.run)
        }
    }

    func onReactionAdd(_ do: @escaping (Sword, Reaction) -> Void) {
        on(.reactionAdd) { data in
            guard let (channel, userID, messageID, emoji) = data as? (TextChannel, Snowflake, Snowflake, Emoji) else {
                return
            }

            let reaction = Reaction(
                channel: channel,
                userID: userID,
                messageID: messageID,
                emoji: emoji
            )

            `do`(self, reaction)
        }
    }

    func onReactionAdd(_ commands: Command<Reaction>...) {
        for command in commands {
            onReactionAdd(command.run)
        }
    }
}
