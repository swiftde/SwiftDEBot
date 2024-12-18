import DiscordBM

let messageCommands: [MessageCommand] = [
    XcodeTypoCommand(),
    XcodeLatestCommand(),
    SwiftEvolutionCommand(),
    AppleStatusCommand(),
    SPICommand(),
    SummarizeCommand(),
    RubyCommand(),

    CowsCommand(),

    HelpCommand(),
    UptimeCommand(),
    PingCommand(),
]

let reactionCommands: [ReactionCommand] = [
    ThisCommand()
]
