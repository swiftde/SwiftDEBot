import AsyncHTTPClient
import DiscordBM
import DiscordLogger
import Foundation
import Logging

let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)

DiscordGlobalConfiguration.logManager = DiscordLogManager(httpClient: httpClient)

// This feels unecessarily complex...
LoggingSystem.bootstrap { label in
    var streamLogHandler = StreamLogHandler.standardOutput(label: label)
    let logHandler: LogHandler
    if let discordLogURL = ProcessInfo.processInfo.environment["DISCORD_LOGS_WEBHOOK_URL"] {
        logHandler = DiscordLogHandler.multiplexLogHandler(
            label: label,
            address: try! .url(discordLogURL),
            makeMainLogHandler: { _, _ in
                streamLogHandler
            })
    } else {
        logHandler = streamLogHandler
    }
    #if DEBUG
        streamLogHandler.logLevel = .debug
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

log.info("Starting")

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
                        log.error("Error during execution of \(type(of: command)): \(error)")
                    }
                }
            }
        case .messageReactionAdd(let reaction):
            Task {
                for command in reactionCommands {
                    do {
                        try await command.run(client: bot.client, reaction: reaction)
                    } catch {
                        log.error("Error during execution of \(type(of: command)): \(error)")
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
