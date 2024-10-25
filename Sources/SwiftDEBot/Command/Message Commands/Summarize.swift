import Foundation
import DiscordBM

struct SummarizeCommand: MessageCommand {
    let helpText = "`!summarize`: Fasse einen Link, eine Nachricht oder Bilder zusammen."

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content == "!summarize" else { return }

        try await client.setTyping(in: message.channel_id)

        do {
            let summary = try await generateSummary(for: message)
            for chunk in summary.maxMessageLengthChunks() {
                try await client.send(chunk, to: message.channel_id)
            }
        } catch let error as SummaryError {
            do {
                switch error {
                case .contentTooShort:
                    try await client.send(
                        "Srsly? Das fasse ich nicht zusammen. Lies das gefälligst selbst.",
                        to: message.channel_id
                    )
                case .noReply:
                    try await client.send(
                        "Schicke bitte `!summarize` als Reply auf eine Nachricht.",
                        to: message.channel_id
                    )
                case .brokenURL, .missingKagiToken, .missingOpenAIToken:
                    try await client.send(
                        "💀 \(error)",
                        to: message.channel_id
                    )
                case .emptySummary:
                    try await client.send(
                        "Das kann ich leider nicht zusammenfassen 🫥: \(error)",
                        to: message.channel_id
                    )
                }
            } catch {
                log.error("Failure to send message: \(error)")
            }
        } catch let error {
            log.error("Failure to send message: \(error)")
        }
    }

    func generateSummary(for message: Gateway.MessageCreate) async throws -> String {
        guard let referencedMessage = message.referenced_message?.value else {
            throw SummaryError.noReply
        }
        var summary: String
        if let url = referencedMessage.content.firstURL {
            summary = try await summarize(url: url)
        } else {
            summary = try await summarize(messageContent: referencedMessage)
        }
        return summary
    }

    func summarize(url: String) async throws -> String {
        log.info("Summarizing \(url)")
        guard let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            log.error("Unable to URL encode \(url)")
            throw SummaryError.brokenURL
        }

        guard let apiToken = ProcessInfo.processInfo.environment["KAGI_API_TOKEN"] else {
            log.error("Necessary env var not found, please set KAGI_API_TOKEN.")
            throw SummaryError.missingKagiToken
        }

        let response = try await httpClient.get(
            "https://kagi.com/api/v0/summarize?target_language=DE&url=\(encodedURL)",
            headers: ["Authorization": "Bot \(apiToken)"],
            response: KagiResponse.self
        )

        if response.data.output.isEmpty {
            throw SummaryError.emptySummary
        }

        return response.data.output
    }

    func summarize(messageContent: Gateway.MessageCreate) async throws -> String {
        log.info("Summarizing message from \(messageContent.author?.mentionHandle ?? "unknown user")")

        guard let apiToken = ProcessInfo.processInfo.environment["OPENAI_API_TOKEN"] else {
            log.error("Necessary env var not found, please set OPENAI_API_TOKEN.")
            throw SummaryError.missingOpenAIToken
        }

        print("Message Length: \(messageContent.content.count)")
        print("Has Attachments: \(!messageContent.attachments.isEmpty)")
        guard messageContent.content.count >= 500 || !messageContent.attachments.isEmpty else {
            throw SummaryError.contentTooShort
        }

        let response = try await httpClient.post(
            "https://api.openai.com/v1/chat/completions",
            headers: ["Authorization": "Bearer \(apiToken)"],
            body: OpenAIRequest(message: messageContent),
            response: OpenAIResponse.self
        )

        guard let summary = response.choices.first else {
            throw SummaryError.emptySummary
        }

        return summary.message.content
    }
}

enum SummaryError: Error {
    case contentTooShort
    case noReply
    case brokenURL
    case missingKagiToken
    case missingOpenAIToken
    case emptySummary
}

private extension String {
    var firstURL: String? {
        if let found = self.firstMatch(of: #/(https?://\S+)/#) {
            return String(found.output.1)
        }
        return nil
    }
}

private struct KagiResponse: Decodable {
    let data: ResponseData

    struct ResponseData: Decodable {
        let output: String
    }
}

struct OpenAIResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
        let finish_reason: String

        struct Message: Decodable {
            let role, content: String
        }
    }
}

private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double

    init(message: Gateway.MessageCreate) {
        self.model = "gpt-4o-mini"

        var content = message.attachments.compactMap { attachment -> Message.ContentUnion.ContentElement? in
            guard let contentType = attachment.content_type, contentType.starts(with: "image/") else { return nil }
            return .init(type: "image_url", text: nil, image_url: .init(url: attachment.url))
        }

        if !message.content.isEmpty {
            content.append(.init(type: "text", text: message.content, image_url: nil))
        }

        self.messages = [
            .init(
                role: "system",
                content: .string("Du bist ein Assistent, der Text und Bildinhalte zusammenfasst. Bitte schreibe eine kurze Zusammenfassung für die folgende Nachricht, bestehend entweder aus Text, Bild oder beidem. Falls beides, dann bezieht sich der Text zwar vermutlich auf das Bild, die Zusammenfassung des Bildinhalts hat aber Vorrang.")
            ),
            .init(role: "user", content: .contentElementArray(content))
        ]
        self.temperature = 0.7
    }

    struct Message: Encodable {
        let role: String
        let content: ContentUnion

        enum ContentUnion: Encodable {
            case contentElementArray([ContentElement])
            case string(String)

            struct ContentElement: Encodable {
                // This could likely be more sensibly represented as a union type, but eh... 🤷
                let type: String
                let text: String?
                let image_url: ImageURL?

                struct ImageURL: Encodable {
                    let url: String
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .string(let stringValue):
                    try container.encode(stringValue)
                case .contentElementArray(let contentElements):
                    try container.encode(contentElements)
                }
            }
        }
    }
}
