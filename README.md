# SwiftDEBot

Our friendly community bot, say hello on [Discord](https://discord.gg/E88g3YrkQV)!

## Development

The Swift toolchain and swift-format come from the nix flake. Enter the dev shell with `nix develop`, or allow the `.envrc` with direnv. Then:

```sh
swift test
swift format format --in-place --recursive --parallel Package.swift Sources Tests
swift format lint --strict --recursive --parallel Package.swift Sources Tests
swift run SwiftDEBot
```

Running the bot needs `DISCORD_TOKEN` and `DISCORD_APP_ID`. With direnv, put them into `.envrc.local` as `export` lines; git ignores that file. [AGENTS.md](AGENTS.md) describes how the bot is structured and how to add a command.
