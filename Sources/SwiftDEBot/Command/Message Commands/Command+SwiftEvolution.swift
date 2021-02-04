import Foundation
import Sword

// Remove me when upgrading to a more current version of Swift.
import Result

extension Command where Trigger == Message {
    static let swiftEvolution = Command(
        run: { bot, message in
            guard message.content.hasPrefix("!se") else { return }
            let query = message.content.components(separatedBy: " ")[1...].joined(separator: " ")
            guard query.trimmingCharacters(in: .whitespacesAndNewlines) != "" else {
                bot.send("Ich weiß nicht wonach ich suchen soll. Bitte schreib' eine Nachricht wie `!se async`", to: message.channel.id)
                return
            }

            bot.setTyping(for: message.channel.id)
            getProposals { result in
                switch result {
                case .failure(let error):
                    bot.send("Ich hatte einen Fehler beim Nachschauen 😵 \(error)", to: message.channel.id)
                case .success(let proposals):
                    guard proposals.count > 0 else {
                        bot.send("Auf swift.org sind keine Proposals mehr gelistet 🤔", to: message.channel.id)
                        return
                    }
                    let matchingQuery = proposals.filter { $0.matches(query: query) }
                    guard matchingQuery.count > 0 else {
                        bot.send("Dazu habe ich leider kein passendes Proposal gefunden 🕵️", to: message.channel.id)
                        return
                    }

                    let joinedProposals = matchingQuery.map { $0.shortDescription }.joined(separator: "\n\n")
                    bot.send(joinedProposals, to: message.channel.id)
                }
            }
        }
    )

    fileprivate static func getProposals(completion: @escaping (Result<[Proposal], String>) -> Void) {
        let proposalsURL = URL(string: "https://data.swift.org/swift-evolution/proposals")!
        let task = URLSession.shared.dataTask(with: proposalsURL) { data, _, error in
            guard error == nil, let data = data else {
                completion(.failure(String(describing: error ?? "keine Daten vorhanden")))
                return
            }
            do {
                let proposals = try JSONDecoder().decode([Proposal].self, from: data)
                completion(.success(proposals.reversed()))
            } catch {
                completion(.failure(String(describing: error)))
            }
        }
        task.resume()
    }
}

fileprivate struct Proposal: Decodable {
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
