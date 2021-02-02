extension Command {
    static let ping = Command.onMessageCreate(
        shouldRun: { message in message.content == "!ping" },
        run: { bot, message in
            bot.send("pong", to: message.channel.id)
        }
    )
}
