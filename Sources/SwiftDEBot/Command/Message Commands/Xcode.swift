import DiscordBM
import Foundation
import FoundationBandAid

struct XcodeTypoCommand: Command {
    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        let content = message.content
        guard content.contains("XCode") || content.contains("xCode"),
            let handle = message.author?.mentionHandle
        else {
            return
        }
        try await client.send("Psst \(handle), das schreibt sich Xcode.", to: message.channel_id)
    }
}

struct XcodeLatestCommand: Command {
    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content == "!xcode" else { return }

        let versions: [XcodeVersion]
        do {
            versions = try await self.latestXcodeVersions()
        } catch {
            try await client.send("Ich hatte einen Fehler beim Nachschauen 😵 \(error)", to: message.channel_id)
            return
        }

        guard let latest = versions.first else {
            try await client.send("xcodereleases.com zeigt keine Versionen an 🤔", to: message.channel_id)
            return
        }
        if latest.isPrerelease, let latestStable = versions.first(where: { $0.isPrerelease == false }) {
            try await client.send(
                """
                Das aktuellste Release ist \(latest.shortDescription)
                Mehr Infos hier: \(latest.detailURLString)

                Das letzte **stabile** Release ist \(latestStable.shortDescription)
                Mehr Infos hier: \(latestStable.detailURLString)
                """, to: message.channel_id)
        } else {
            try await client.send(
                """
                Das aktuellste Release von Xcode ist \(latest.shortDescription)
                Mehr Infos hier: \(latest.detailURLString)
                """, to: message.channel_id)
        }
    }

    fileprivate func latestXcodeVersions() async throws -> [XcodeVersion] {
        let xcodeReleasesURL = URL(string: "https://xcodereleases.com/data.json")!
        let (data, _) = try await URLSession.shared.data(from: xcodeReleasesURL)
        return try JSONDecoder().decode([XcodeVersion].self, from: data)
    }
}

private struct XcodeVersion: Decodable {
    let name: String
    let version: Version
    let date: ReleaseDate
    let links: Links?

    var isPrerelease: Bool {
        return version.release.release == nil || version.release.release == false
    }

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
            let dateComponents = DateComponents(
                calendar: Calendar(identifier: .gregorian), year: year, month: month, day: day)
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
        return "\(name) **\(version.number) \(releaseStr)**(\(version.build)) vom \(date.germanFormatted)"
    }

    var detailURLString: String {
        return links?.notes?.url.absoluteString ?? "Keine Detail-URL vorhanden"
    }
}
