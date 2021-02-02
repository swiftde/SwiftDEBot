extension MessageCommand {
    static let xcode = MessageCommand(
        shouldRun: { message in
            let content = message.content
            return content.contains("XCode") || content.contains("xCode")
        },
        run: { bot, message in
            guard let handle = message.author?.mentionHandle else { return }
            bot.send("Psst \(handle), das schreibt sich Xcode.", to: message.channel.id)
        })
}
