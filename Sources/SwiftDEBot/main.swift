import AsyncHTTPClient
import DiscordBM
import Foundation
import Logging


LoggingSystem.bootstrap { label in
    var logHandler = StreamLogHandler.standardOutput(label: label)
    #if DEBUG
    logHandler.logLevel = .debug
    #endif
    return logHandler
}


let log = Logger(label: "swiftde.bot")

guard
    let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"],
    let appID = ProcessInfo.processInfo.environment["DISCORD_APP_ID"]
else {
    fatalError("Necessary env vars not found, please set DISCORD_TOKEN and/or DISCORD_APP_ID.")
}

let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)

let bot = BotGatewayManager(
    eventLoopGroup: httpClient.eventLoopGroup,
    httpClient: httpClient,
    token: token,
    appId: appID,
    presence: .init(
        activities: [
            .init(name: "swiftc -Ounchecked", type: .competing)
        ],
        status: .online,
        afk: false
    ),
    intents: [
        .directMessages,
        .guildMessages,
        .messageContent,
        .guildMessageReactions,
    ]
)

log.info("Starting with version: \(CurrentVersion.git)")

Task {
    await bot.addEventHandler { event in
        switch event.data {
        case .messageCreate(let message):
            guard !(message.author?.bot ?? false) else { return }

            Task {
                for command in messageCommands {
                    do {
                        try await command.run(client: bot.client, message: message)
                    } catch {
                        log.error("Error during execution of \(type(of: command)): \(error.localizedDescription)")
                    }
                }
            }
        case .messageReactionAdd(let reaction):
            Task {
                for command in reactionCommands {
                    do {
                        try await command.run(client: bot.client, reaction: reaction)
                    } catch {
                        log.error("Error during execution of \(type(of: command)): \(error.localizedDescription)")
                    }
                }
            }
        default:
            break
        }
    }

    await bot.connect()
}

RunLoop.current.run()
