import DiscordBM
import Foundation

struct iPhoneTypoCommand: MessageCommand {
    let helpText = ""

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        let content = message.content
        guard content.contains("Iphone") || content.contains("IFöhn") || content.contains("ipHone") || content.contains("IPhone"),
            let handle = message.author?.mentionHandle
        else {
            return
        }
        try await client.send("Psst \(handle), das schreibt sich iPhone.", to: message.channel_id)
    }
}

struct iPadTypoCommand: MessageCommand {
    let helpText = ""

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        let content = message.content
        guard content.contains("Ipad") || content.contains("IPad"),
            let handle = message.author?.mentionHandle
        else {
            return
        }
        try await client.send("Psst \(handle), das schreibt sich iPad.", to: message.channel_id)
    }
}
