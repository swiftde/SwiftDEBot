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
    
    TypoCommand(),
]

let reactionCommands: [ReactionCommand] = [
    ThisCommand()
]
