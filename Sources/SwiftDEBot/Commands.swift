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
    
    iPhoneTypoCommand(),
    iPadTypoCommand(),
]

let reactionCommands: [ReactionCommand] = [
    ThisCommand()
]
