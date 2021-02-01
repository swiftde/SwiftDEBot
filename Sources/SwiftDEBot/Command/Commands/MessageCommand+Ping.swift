extension MessageCommand {
    static let ping = MessageCommand(
        shouldRun: { message in message.content == "!ping" },
        run: { bot, message in
            bot.send("pong", to: message.channel.id)
        }
    )
}
