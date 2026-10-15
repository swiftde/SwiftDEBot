import DiscordBM

let messageCommands: [MessageCommand] = [
  XcodeLatestCommand(),
  SwiftEvolutionCommand(),
  AppleStatusCommand(),
  SPICommand(),
  SummarizeCommand(),
  FactCheckCommand(),

  CowsCommand(),

  HelpCommand(),
  UptimeCommand(),
  PingCommand(),

  TypoCommand(),
]

let reactionCommands: [ReactionCommand] = [
  AnimatedEmojiCommand()
]
