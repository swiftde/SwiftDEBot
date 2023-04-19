import DiscordBM

struct AppleStatusCommand: MessageCommand {
    let helpText = "`!applestatus` oder `!applestatus <query>`: Gibt aus ob incidents bei Apple-Diensten bekannt sind. Wahlweise mit Filter für spezifische Dienste, e.g. 'iCloud Mail'."

    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws {
        guard message.content.hasPrefix("!applestatus") else { return }
        let serviceQuery = message.content.queryString ?? ""

        log.debug("!applestatus '\(serviceQuery)'")

        // There's a second list of dev services on https://developer.apple.com/system-status/, but I can't find a URL
        // for the raw data like the XHR request on https://www.apple.com/support/systemstatus/.
        let serviceStatuses = try await httpClient.get(
            "https://www.apple.com/support/systemstatus/data/system_status_en_US.js", response: StatusResponse.self)

        guard serviceQuery != "-list" else {
            try await client.send(serviceStatuses.services.map(\.serviceName).joined(separator: ", "), to: message.channel_id)
            return
        }

        var affectedServices = serviceStatuses.services
            .filter { !$0.events.isEmpty }

        if serviceQuery != "" {
            affectedServices = affectedServices.filter { $0.serviceName.lowercased().contains(serviceQuery) }
        }

        guard !affectedServices.isEmpty else {
            try await client.send("Dazu sind mir keine Statusmeldungen bekannt.", to: message.channel_id)
            return
        }

        let serviceMessages = affectedServices.map(\.description)

        for chunk in serviceMessages.chunks(ofCount: 4) {
            try await client.send(chunk.joined(separator: "\n\n"), to: message.channel_id)
        }
    }
}

fileprivate struct StatusResponse: Decodable {
    let services: [ServiceStatus]

    struct ServiceStatus: Decodable {
        let serviceName: String
        let events: [Event]

        var description: String {
            "**\(serviceName)**\n" + events.map(\.description).joined(separator: "\n\n")
        }

        struct Event: Decodable {
            let message: String
            let eventStatus: String
            let statusType: String
            let usersAffected: String
            let datePosted: String
            let startDate: String
            let endDate: String

            var description: String {
                """
                \(statusType) \(eventStatus)
                \(startDate) - \(endDate)
                \(usersAffected)
                \(message)
                """
            }
        }
    }
}
