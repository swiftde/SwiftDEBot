import AsyncHTTPClient
import DiscordBM
import Foundation

enum OpenRouterError: Error {
  case missingAPIKey
}

extension HTTPClient {
  /// Returns the text of the first choice, or nil if the model returned none or only whitespace.
  func openRouterCompletion(_ request: ChatCompletionRequest) async throws -> String? {
    guard let apiKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] else {
      log.error("Necessary env var not found, please set OPENROUTER_API_KEY.")
      throw OpenRouterError.missingAPIKey
    }

    let response = try await post(
      "https://openrouter.ai/api/v1/chat/completions",
      headers: ["Authorization": "Bearer \(apiKey)"],
      body: request,
      response: ChatCompletionResponse.self
    )
    guard let content = response.choices.first?.message.content,
      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return nil }
    return content
  }
}

struct ChatCompletionRequest: Encodable {
  var model = "z-ai/glm-5.3-flash"
  let messages: [Message]
  let temperature: Double
  var tools: [Tool]? = nil

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
        let imageURL: ImageURL?

        enum CodingKeys: String, CodingKey {
          case type, text
          case imageURL = "image_url"
        }

        struct ImageURL: Encodable {
          let url: String
        }

        static func text(_ text: String) -> Self {
          .init(type: "text", text: text, imageURL: nil)
        }

        /// The image attachments of a message as content elements.
        static func images(of message: Gateway.MessageCreate) -> [Self] {
          message.attachments.compactMap { attachment in
            guard let contentType = attachment.content_type, contentType.starts(with: "image/") else { return nil }
            return .init(type: "image_url", text: nil, imageURL: .init(url: attachment.url))
          }
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

  /// A tool that OpenRouter runs itself within the request, so the response holds the final answer.
  struct Tool: Encodable {
    let type: String
    let parameters: [String: Int]

    /// See https://openrouter.ai/docs/guides/features/server-tools/web-search
    static func webSearch(maxResults: Int, maxUses: Int) -> Self {
      .init(type: "openrouter:web_search", parameters: ["max_results": maxResults, "max_uses": maxUses])
    }
  }
}

private struct ChatCompletionResponse: Decodable {
  let choices: [Choice]

  struct Choice: Decodable {
    let message: Message

    struct Message: Decodable {
      let content: String?
    }
  }
}
