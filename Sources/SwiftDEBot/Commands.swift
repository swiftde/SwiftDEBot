import DiscordBM

let messageCommands: [MessageCommand] = [
    XcodeTypoCommand(),
    XcodeLatestCommand(),
    SwiftEvolutionCommand(),
    AppleStatusCommand(),
    SPICommand(),
    SummarizeCommand(),

    CowsCommand(),

    HelpCommand(),
    UptimeCommand(),
    PingCommand(),
]

let reactionCommands: [ReactionCommand] = [
    ThisCommand()
]
