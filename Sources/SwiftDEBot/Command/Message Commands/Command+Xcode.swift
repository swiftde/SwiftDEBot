import Foundation
import Sword

// Remove me when upgrading to a more current version of Swift.
import Result

extension Command where Trigger == Message {
    static let xcodeTypo = Command(
        run: { bot, message in
            let content = message.content
            guard content.contains("XCode") || content.contains("xCode"),
                  let handle = message.author?.mentionHandle else {
                return
            }
            bot.send("Psst \(handle), das schreibt sich Xcode.", to: message.channel.id)
        }
    )

    static let xcodeLatest = Command(
        run: { bot, message in
            guard message.content == "!xcode" else { return }
            bot.setTyping(for: message.channel.id)
            latestXcodeVersions { result in
                switch result {
                case .failure(let error):
                    bot.send("Ich hatte einen Fehler beim Nachschauen 😵 \(error.error)", to: message.channel.id)
                case .success(let versions):
                    guard let latest = versions.first else {
                        bot.send("xcodereleases.com zeigt keine Versionen an 🤔", to: message.channel.id)
                        return
                    }
                    bot.send(latest.shortDescription, to: message.channel.id)
                }
            }
        }
    )

    fileprivate static func latestXcodeVersions(completion: @escaping (Result<[XcodeVersion], XcodeVersionCheckError>) -> Void) {
        let xcodeReleasesURL = URL(string: "https://xcodereleases.com/data.json")!
        let task = URLSession.shared.dataTask(with: xcodeReleasesURL) { data, response, error in
            guard error == nil, let data = data else {
                completion(.failure(XcodeVersionCheckError(error: error?.localizedDescription ?? "keine Daten vorhanden")))
                return
            }
            do {
                let versions = try JSONDecoder().decode([XcodeVersion].self, from: data)
                completion(.success(versions))
            } catch {
                dump(error)
                completion(.failure(XcodeVersionCheckError(error: error.localizedDescription)))
            }
        }
        task.resume()
    }
}

fileprivate struct XcodeVersionCheckError: Error {
    let error: String
}

fileprivate struct XcodeVersion: Decodable {
    let name: String
    let version: Version
    let date: ReleaseDate
    let links: Links?

    struct Version: Decodable {
        let number: String
        let build: String
        let release: Release

        struct Release: Decodable {
            let release: Bool?
            let rc: Int?
            let gm: Bool?
            let gmSeed: Int?
            let beta: Int?

            var description: String? {
                if let release = release, release == true {
                    return nil
                } else if let rc = rc {
                    return "RC \(rc)"
                } else if let gm = gm, gm == true {
                    return "GM"
                } else if let gmSeed = gmSeed {
                    return "GM Seed \(gmSeed)"
                } else if let beta = beta {
                    return "Beta \(beta)"
                }
                return nil
            }
        }
    }

    struct ReleaseDate: Decodable {
        let year: Int
        let month: Int
        let day: Int

        var germanFormatted: String {
            let dateComponents = DateComponents(calendar: Calendar(identifier: .gregorian), year: year, month: month, day: day)
            guard let date = dateComponents.date else { return "\(day).\(month).\(year)" }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "de_DE")
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
            return formatter.string(from: date)
        }
    }

    struct Links: Decodable {
        let notes: Notes?

        struct Notes: Decodable {
            let url: URL
        }
    }

    var shortDescription: String {
        var releaseStr = ""
        if let release = version.release.description {
            releaseStr = release + " "
        }
        return """
        Die aktuellste Xcode Version ist \(name) \(version.number) \(releaseStr)(\(version.build)) vom \(date.germanFormatted).
        Mehr Infos hier: \(links?.notes?.url.absoluteString ?? "Keine Detail-URL vorhanden")
        """
    }
}
