import DiscordBM

struct SPICommand: MessageCommand {
    let helpText = "`!spi <query>`: Suche nach Packages im Swift Package Index."

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content.hasPrefix("!spi") else { return }
        guard let query = message.content.queryString, !query.isEmpty else {
            try await client.send(
                "Ich weiß nicht wonach ich suchen soll. Bitte schreib' eine Nachricht wie `!spi lighter`.",
                to: message.channel_id)
            return
        }
        guard let urlQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            log.error("Unable to URL encode \(query)")
            return
        }

        try await client.setTyping(in: message.channel_id)

        let response = try await httpClient.get(
            "https://swiftpackageindex.com/api/search?query=\(urlQuery)", response: SPIResponse.self)
        let searchResults = response.results
            .compactMap {
                if case .package(let package) = $0 {
                    return package
                }
                return nil
            }
            .prefix(10)

        guard !searchResults.isEmpty else {
            try await client.send("Dazu konnte ich leider nichts finden, probier's vielleicht mal hier: <https://github.com/search?q=language:swift%20\(urlQuery)&type=repositories>", to: message.channel_id)
            return
        }

        for chunk in searchResults.map(\.description).chunks(ofCount: 4) {
            try await client.send(chunk.joined(separator: "\n"), to: message.channel_id)
        }
    }
}

private struct SPIResponse: Decodable {
    let results: [SearchResult]

    enum SearchResult: Decodable {
        case author
        case keyword
        case package(Package)
    }

    struct Package: Decodable {
        let packageName: String
        let repositoryName: String
        let repositoryOwner: String
        let summary: String
        let stars: Int
        let packageURL: String
        let hasDocs: Bool

        var spiURL: String {
            "https://swiftpackageindex.com\(packageURL)"
        }

        var docsURL: String? {
            guard hasDocs else { return nil }
            return "\(spiURL)/documentation"
        }

        var description: String {
            """
            **\(packageName)** \(stars)⭐
            \(summary)
            <\(spiURL)>
            """
        }
    }
}
