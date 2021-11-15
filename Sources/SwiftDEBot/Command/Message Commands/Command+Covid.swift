import Foundation
import Sword

// Remove me when upgrading to a more current version of Swift.
import Result

extension Command where Trigger == Message {
    static let impfstatus = Command(
        run: { bot, message in
            guard message.content.starts(with: "!impfstatus") else { return }

            var query = message.content.components(separatedBy: " ")[1...].joined(separator: " ")
            if query.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
                query = "Deutschland"
            }
            if query.lowercased() == "nrw" {
                query = "Nordrhein-Westfalen"
            }

            if query == "top" {
                postHighscores(bot: bot, message: message)
            } else {
                postSingleRegionStats(for: query, bot: bot, message: message)
            }
        }
    )

    fileprivate static func postSingleRegionStats(for region: String, bot: Sword, message: Message) {
        bot.setTyping(for: message.channel.id)
        getVaccinationData { result in
            switch result {
            case .failure(let error):
                bot.send("Ich hatte einen Fehler beim Nachschauen 😵 \(error)", to: message.channel.id)
            case .success(let response):
                let regionMatch = response.data.first { $0.name.lowercased() == region.lowercased() }?.description ?? "Ich habe leider keine aktuellen Daten für \(region) finden können."
                bot.send(regionMatch, to: message.channel.id)
            }
        }
    }

    fileprivate static func postHighscores(bot: Sword, message: Message) {
        bot.setTyping(for: message.channel.id)
        getVaccinationData { result in
            switch result {
            case .failure(let error):
                bot.send("Ich hatte einen Fehler beim Nachschauen 😵 \(error)", to: message.channel.id)
            case .success(let response):
                let sortedStates = response.data
                    .filter(\.isState)
                    .sorted { $0.fullyVaccinated.quote > $1.fullyVaccinated.quote }

                var response = "**Impfhighscores**\n```"
                for (idx, state) in zip(sortedStates.indices, sortedStates) {
                    let space = idx < 9 ? "  " : " "
                    response += "\(idx+1).\(space)\(state.fullyVaccinated.quote.twoDecimals)% \(state.name)\n"
                }
                response += "```"
                bot.send(response, to: message.channel.id)
            }
        }
    }

    fileprivate static func getVaccinationData(completion: @escaping (Result<VaccinationResponse, String>) -> Void) {
        let vaccinationDataURL = URL(string: "https://rki-vaccination-data.vercel.app/api/v2")!
        HTTP.shared.get(url: vaccinationDataURL) { (result: Result<VaccinationResponse, Error>) in
            switch result {
            case .failure(let error):
                completion(.failure(error.localizedDescription))
            case .success(let response):
                completion(.success(response))
            }
        }
    }
}

fileprivate struct VaccinationResponse: Decodable {
//    let lastUpdate: Date
    let data: [RegionData]

    struct RegionData: Decodable, CustomStringConvertible {
        let name: String
        let isState: Bool
        let inhabitants: Int
        let vaccinatedAtLeastOnce: VaccinationData
        let fullyVaccinated: VaccinationData

        struct VaccinationData: Decodable {
            let doses: Int
            let quote: Double
            let differenceToThePreviousDay: Int
        }

        var description: String {
            let prefix = name == "Saarland" ? "Im" : "In"
            return """
            \(prefix) **\(name)** haben sich \(vaccinatedAtLeastOnce.quote.twoDecimals)% mindestens einmal impfen lassen. **\(fullyVaccinated.quote.twoDecimals)% sind vollständig geimpft**. Das sind \(vaccinatedAtLeastOnce.differenceToThePreviousDay) bzw. \(fullyVaccinated.differenceToThePreviousDay) mehr als gestern.
            """
        }
    }
}

extension Double {
    var twoDecimals: String {
        return String(format: "%.2f", self)
    }
}
