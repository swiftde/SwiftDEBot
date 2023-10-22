import Foundation
import DiscordBM

struct SummarizeCommand: MessageCommand {
    let helpText = "`!summarize`: Fasse einen Link im Reply zusammen."

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content == "!summarize" else { return }

        guard let replyContent = message.referenced_message?.value.content else {
            try await client.send(
                "Schicke bitte `!summarize` als Reply auf eine Nachricht mit einem Link.",
                to: message.channel_id
            )
            return
        }
        guard let url = replyContent.firstURL else {
            try await client.send(
                "In der referenzierten Nachricht sehe ich leider keine URL 🤨",
                to: message.channel_id
            )
            return
        }
        log.info("Summarizing \(url)")

        try await client.setTyping(in: message.channel_id)

        guard let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            log.error("Unable to URL encode \(url)")
            return
        }

        guard let apiToken = ProcessInfo.processInfo.environment["KAGI_API_TOKEN"] else {
            log.error("Necessary env var not found, please set KAGI_API_TOKEN.")
            return
        }

        let response = try await httpClient.get(
            "https://kagi.com/api/v0/summarize?target_language=DE&url=\(encodedURL)",
            headers: ["Authorization": "Bot \(apiToken)"],
            response: KagiResponse.self
        )

        let summary = response.data.output

        guard !summary.isEmpty else {
            try await client.send(
                "Das kann ich leider nicht zusammenfassen 🫥",
                to: message.channel_id
            )
            return
        }

        try await client.send(summary, to: message.channel_id)
    }
}

private extension String {
    var firstURL: URL? {
        var foundURL: URL?
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        detector?.enumerateMatches(in: self, options: [], range: .init(location: 0, length: self.utf16.count), using: { (result, _, _) in
            if let match = result, let url = match.url {
                foundURL = url
            }
        })
        return foundURL
    }
}

 private struct KagiResponse: Decodable {
     let data: ResponseData

     struct ResponseData: Decodable {
         let output: String
     }
 }
