import DiscordBM
import Foundation

struct SummarizeCommand: MessageCommand {
  let helpText = "`!summarize`: Fasse einen Link, eine Nachricht oder Bilder zusammen."

  func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
    guard message.content.invocation(of: "!summarize") != nil else { return }

    do {
      let summary = try await client.whileTyping(in: message.channel_id) {
        try await generateSummary(for: message)
      }
      for chunk in summary.maxMessageLengthChunks() {
        try await client.sendModelOutput(chunk, to: message.channel_id)
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
        case .brokenURL, .missingKagiToken:
          try await client.send(
            "💀 \(error)",
            to: message.channel_id
          )
        case .emptySummary:
          try await client.send(
            "Das kann ich leider nicht zusammenfassen 🫥",
            to: message.channel_id
          )
        }
      } catch {
        log.error("Failure to send message: \(error)")
      }
    } catch OpenRouterError.missingAPIKey {
      try await client.send("💀 OPENROUTER_API_KEY fehlt", to: message.channel_id)
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

    guard messageContent.content.count >= 500 || !messageContent.attachments.isEmpty else {
      throw SummaryError.contentTooShort
    }

    var content = ChatCompletionRequest.Message.ContentUnion.ContentElement.images(of: messageContent)
    if !messageContent.content.isEmpty {
      content.append(.text(messageContent.content))
    }
    guard !content.isEmpty else {
      throw SummaryError.emptySummary
    }

    let request = ChatCompletionRequest(
      messages: [
        .init(
          role: "system",
          content: .string(
            "Du bist ein Assistent, der Text und Bildinhalte zusammenfasst. Bitte schreibe eine kurze Zusammenfassung für die folgende Nachricht, bestehend entweder aus Text, Bild oder beidem. Falls beides, dann bezieht sich der Text zwar vermutlich auf das Bild, die Zusammenfassung des Bildinhalts hat aber Vorrang. Die Zusammenfassung muss unabhängig von der Sprache des ursprünglichen Inhalts auf Deutsch sein."
          )
        ),
        .init(role: "user", content: .contentElementArray(content)),
      ],
      temperature: 0.7
    )

    guard let summary = try await httpClient.openRouterCompletion(request) else {
      throw SummaryError.emptySummary
    }

    return summary
  }
}

enum SummaryError: Error {
  case contentTooShort
  case noReply
  case brokenURL
  case missingKagiToken
  case emptySummary
}

extension String {
  fileprivate var firstURL: String? {
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
