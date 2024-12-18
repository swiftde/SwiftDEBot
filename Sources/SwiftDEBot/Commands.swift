import DiscordBM

let messageCommands: [MessageCommand] = [
    XcodeLatestCommand(),
    SwiftEvolutionCommand(),
    AppleStatusCommand(),
    SPICommand(),
    SummarizeCommand(),

    CowsCommand(),

    HelpCommand(),
    UptimeCommand(),
    PingCommand(),
    
    TypoCommand(),
]

let reactionCommands: [ReactionCommand] = [
    ThisCommand()
]
