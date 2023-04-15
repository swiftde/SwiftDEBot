import DiscordBM

let messageCommands: [MessageCommand] = [
    XcodeTypoCommand(),
    XcodeLatestCommand(),
    SwiftEvolutionCommand(),

    CowsCommand(),

    HelpCommand(),
    VersionCommand(),
    PingCommand(),
    HalloCommand(),
]

let reactionCommands: [ReactionCommand] = [
    ThisCommand(),
]
