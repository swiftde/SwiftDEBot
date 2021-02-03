import Sword

extension Command where Trigger == Message {
    static let xcode = Command(
        run: { bot, message in
            let content = message.content
            guard content.contains("XCode") || content.contains("xCode"),
                  let handle = message.author?.mentionHandle else {
                return
            }
            bot.send("Psst \(handle), das schreibt sich Xcode.", to: message.channel.id)
        }
    )
}
