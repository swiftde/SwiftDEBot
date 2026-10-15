# AGENTS.md

SwiftDEBot ("Schwifty") is the Discord bot of the German Swift community. It is a single Swift executable built on [DiscordBM](https://github.com/MahdiBM/DiscordBM). User-facing bot text is in German.

## Commands

```sh
swift build                          # debug build, enables debug-level logging
swift build --configuration release  # what CI and the Dockerfile run
swift run SwiftDEBot                 # needs DISCORD_TOKEN and DISCORD_APP_ID
```

CI builds inside the `swift:5.9` Docker image on Linux, so code must compile with Swift 5.9 and without Apple-only frameworks. To reproduce CI locally:

```sh
docker run --rm -v "$(pwd):/src" -w /src swift:5.9 swift build --configuration release
```

There is no test target, linter or formatter. Pushes to `main` build and publish `ghcr.io/swiftde/swiftdebot:latest`, which `docker-compose.yml` deploys.

## Environment

`DISCORD_TOKEN` and `DISCORD_APP_ID` are required; the bot exits without them. `DISCORD_LOGS_WEBHOOK_URL` additionally forwards logs to a Discord webhook. `!summarize` needs `KAGI_API_TOKEN` for links and `OPENAI_API_TOKEN` for messages and images; it reports a missing token in the channel instead of failing at startup.

## Architecture

`main.swift` sets up logging and the gateway connection, then dispatches every gateway event to all registered commands. Commands do not register triggers. Each command receives every non-bot message (or every added reaction) and decides itself whether to act, usually with a `guard` on `message.content`. Commands run sequentially per event, and an error in one is logged without stopping the others.

Adding a command means:

1. Create a type conforming to `MessageCommand` or `ReactionCommand` (`Command/Command.swift`) under `Command/Message Commands/` or `Command/Reaction Commands/`.
2. Register an instance in `messageCommands` or `reactionCommands` in `Commands.swift`. Order there sets execution order and the order of entries in `!help`.

`helpText` on a message command feeds `!help`. An empty string hides the command from it.

Shared helpers live in `Utils/`. `DiscordClient` extensions provide `send`, `addReaction` and `setTyping`. `HTTPClient` extensions provide `get`/`post` that decode JSON responses and throw on non-200 status. A global `httpClient` and `log` are defined in `main.swift` and used directly by commands. `String` helpers include `maxMessageLengthChunks()` for splitting output to Discord's message length limit.
