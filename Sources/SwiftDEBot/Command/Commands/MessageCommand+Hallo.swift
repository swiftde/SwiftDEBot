extension MessageCommand {
    static let hello = MessageCommand(
        shouldRun: { message in message.content == "!hallo" },
        run: { bot, message in
            if let name = message.author?.username {
                bot.send("Hi \(name) :wave:", to: message.channel.id)
            } else {
                bot.send("Hi :wave:", to: message.channel.id)
            }
        }
    )
}
