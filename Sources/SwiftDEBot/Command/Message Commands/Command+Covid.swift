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

            bot.setTyping(for: message.channel.id)
            getVaccinationData { result in
                switch result {
                case .failure(let error):
                    bot.send("Ich hatte einen Fehler beim Nachschauen 😵 \(error)", to: message.channel.id)
                case .success(let response):
                    let queryMatch = response.data.first { $0.name.lowercased() == query.lowercased() }?.description ?? "Ich habe leider keine aktuellen Daten für \(query) finden können."
                    bot.send(queryMatch, to: message.channel.id)
                }
            }
        }
    )

    fileprivate static func getVaccinationData(completion: @escaping (Result<VaccinationResponse, String>) -> Void) {
        let vaccinationDataURL = URL(string: "https://rki-vaccination-data.vercel.app/api/v2")!
        let task = URLSession.shared.dataTask(with: vaccinationDataURL) { data, _, error in
            guard error == nil, let data = data else {
                completion(.failure(String(describing: error ?? "keine Daten vorhanden")))
                return
            }
            do {
                let vaccinationResponse = try JSONDecoder().decode(VaccinationResponse.self, from: data)
                completion(.success(vaccinationResponse))
            } catch {
                completion(.failure(String(describing: error)))
            }
        }
        task.resume()
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
        String(format: "%.2f", self)
    }
}
