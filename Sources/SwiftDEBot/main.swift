import AsyncHTTPClient
import DiscordBM
import Foundation
import Logging

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

Task {
    await bot.addEventHandler { event in
        switch event.data {
        case .messageCreate(let message):
            guard !(message.author?.bot ?? false) else { return }

            Task {
                for command in commands {
                    try? await command.run(client: bot.client, message: message)
                }
            }
        default:
            break
        }
    }

    await bot.connect()
}

RunLoop.current.run()

//let bot = Sword(token: token)
//
//bot.editStatus(to: "", playing: "swiftc -Ounchecked")
//
//bot.onMessageCreate(
//    .hello,
//    .impfstatus,
//    .kompilat,
//    .ping,
//    .xcodeTypo,
//    .xcodeLatest,
//    .vaca,
//    .swiftEvolution
//)
//
//bot.onReactionAdd(
//    .this
//)
//
//bot.connect()
