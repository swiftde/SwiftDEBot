import DiscordBM
import Foundation

struct TypoCommand: MessageCommand {
    let helpText = "Hilft bei der Korrektur von Tippfehlern in Nachrichten."

    let trigger: [String: [String]] = [
        "iPhone": ["Iphone", "ipPhone", "IPhone", "IFöhn"],
        "iPad": ["IPad", "Ipad"]
    ]
    
    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        let content = message.content
        
        for (correctWord, typos) in trigger {
            if typos.contains(where: content.contains),
               let handle = message.author?.mentionHandle {
                try await client.send("Psst \(handle), das schreibt sich \(correctWord).", to: message.channel_id)
                break
            }
        }
    }
}
