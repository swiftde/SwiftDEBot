import Foundation
import Sword

guard let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] else {
    fatalError("No token found in environment, please set DISCORD_TOKEN.")
}
let bot = Sword(token: token)

bot.editStatus(to: "", playing: "swiftc -Ounchecked")

bot.onMessageCreate(
    .hello,
    .ping,
    .xcodeTypo,
    .xcodeLatest,
    .swiftEvolution
)

bot.onReactionAdd(
    .this
)

bot.connect()
