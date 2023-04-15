import DiscordBM
import Foundation
import Algorithms

struct SwiftEvolutionCommand: MessageCommand {
    let helpText = "`!se <query>`: Suche nach Swift Evolution proposals, entweder anhand einer Nummer oder eines Suchbegriffs."

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content.hasPrefix("!se") else { return }
        let query = message.content.components(separatedBy: " ")[1...].joined(separator: " ")
        guard query.trimmingCharacters(in: .whitespacesAndNewlines) != "" else {
            try await client.send(
                "Ich weiß nicht wonach ich suchen soll. Bitte schreib' eine Nachricht wie `!se async`.",
                to: message.channel_id)
            return
        }

        try await client.setTyping(in: message.channel_id)

        let proposals: [Proposal]
        do {
            proposals = try await httpClient.get("https://download.swift.org/swift-evolution/proposals.json",
                                                 response: [Proposal].self)
        } catch {
            try await client.send("Ich hatte einen Fehler beim Nachschauen 😵 \(error)", to: message.channel_id)
            return
        }

        guard proposals.count > 0 else {
            try await client.send("Auf swift.org sind keine Proposals mehr gelistet 🤔", to: message.channel_id)
            return
        }

        let matchingQuery = proposals.filter { $0.matches(query: query) }
        log.debug("\(matchingQuery.count) SE proposal(s) matching query '\(query)'")

        guard matchingQuery.count > 0 else {
            try await client.send("Dazu habe ich leider kein passendes Proposal gefunden 🕵️", to: message.channel_id)
            return
        }
        guard matchingQuery.count < 12 else {
            try await client.send("""
            Zu der Suche gibt's mehr als ein Dutzend Proposals. Versuch's lieber mit einem etwas genauerem Suchbegriff.
            """, to: message.channel_id)
            return
        }

        let proposalDescriptions = matchingQuery.map { $0.shortDescription }

        for chunk in proposalDescriptions.chunks(ofCount: 4) {
            try await client.send(chunk.joined(separator: "\n\n"), to: message.channel_id)
        }
    }
}

private struct Proposal: Decodable {
    let id: String
    let title: String
    let link: String
    let summary: String
    let authors: [Author]
    let status: Status

    struct Author: Decodable {
        let name: String
    }

    struct Status: Decodable {
        let state: String
        let version: String?
        let start: String?
        let end: String?

        static var inputDateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "y-MM-dd"
            return formatter
        }()

        static var outputDateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "de_DE")
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
            return formatter
        }()

        var description: String {
            switch (version, start, end) {
            case (let .some(version), nil, nil):
                return "\(state) Swift \(version)"
            case (nil, let .some(start), let .some(end)):
                guard let startDate = Status.inputDateFormatter.date(from: start),
                    let endDate = Status.inputDateFormatter.date(from: end)
                else { return state }
                let startStr = Status.outputDateFormatter.string(from: startDate)
                let endStr = Status.outputDateFormatter.string(from: endDate)
                return "\(state) \(startStr)-\(endStr)"
            default:
                return state
            }
        }
    }

    func matches(query: String) -> Bool {
        return id.lowercased().contains(query.lowercased())
            || title.lowercased().contains(query.lowercased())
    }

    var shortDescription: String {
        return """
            **\(id)** \(title.trimmingCharacters(in: .whitespacesAndNewlines))
            Autor(en): \(authors.map { $0.name }.joined(separator: ", "))
            Status: \(status.description)
            <https://github.com/apple/swift-evolution/blob/main/proposals/\(link)>
            """
    }
}
