# AGENTS.md

SwiftDEBot ("Schwifty") is the Discord bot of the German Swift community. It is a single Swift executable built on [DiscordBM](https://github.com/MahdiBM/DiscordBM). User-facing bot text is in German.

## Commands

The nix flake's dev shell (`nix develop`, or direnv via `.envrc`) provides the Swift toolchain and swift-format. Run all commands inside it.

```sh
swift build                          # debug build, enables debug-level logging
swift run SwiftDEBot                 # needs DISCORD_TOKEN and DISCORD_APP_ID
swift test                           # all tests
swift test --filter QueryStringTests # one suite or test
swift format format --in-place --recursive --parallel Package.swift Sources Tests
swift format lint --strict --recursive --parallel Package.swift Sources Tests
```

CI runs the lint and test steps on Linux, so code must build without Apple-only frameworks. The Swift version of the nixpkgs revision pinned in `flake.lock` and `SWIFT_VERSION` in the `Dockerfile` must match; `nix flake check` verifies this, and CI runs it.

Tests use Swift Testing with [PropertyBased](https://github.com/x-sheep/swift-property-based) for property-based tests. They `@testable import` the executable target. Top-level code in `main.swift` does not run in tests, so the globals defined there (`httpClient`, `log`, `bot`) are never initialized and must not be used. Logic worth testing belongs in the helpers in `Utils/` or in a command's own pure functions.

Pushes to `main` build and publish `ghcr.io/swiftde/swiftdebot:latest`, which `docker-compose.yml` deploys.

## Environment

`DISCORD_TOKEN` and `DISCORD_APP_ID` are required; the bot exits without them. `DISCORD_LOGS_WEBHOOK_URL` additionally forwards logs to a Discord webhook. `!summarize` needs `KAGI_API_TOKEN` for links and `OPENAI_API_TOKEN` for messages and images; it reports a missing token in the channel instead of failing at startup.

## Architecture

`main.swift` sets up logging and the gateway connection, then dispatches every gateway event to all registered commands. Commands do not register triggers. Each command receives every non-bot message (or every added reaction) and decides itself whether to act. Commands with a `!` trigger use `message.content.invocation(of: "!name")` (`Command/Command.swift`), which matches the whole command word case-insensitively and returns the trimmed argument. Commands run sequentially per event, and an error in one is logged without stopping the others.

Adding a command means:

1. Create a type conforming to `MessageCommand` or `ReactionCommand` (`Command/Command.swift`) under `Command/Message Commands/` or `Command/Reaction Commands/`.
2. Register an instance in `messageCommands` or `reactionCommands` in `Commands.swift`. Order there sets execution order and the order of entries in `!help`.

`helpText` on a message command feeds `!help`. An empty string hides the command from it.

Shared helpers live in `Utils/`. `DiscordClient` extensions provide `send`, `addReaction` and `setTyping`. `HTTPClient` extensions provide `get`/`post` that decode JSON responses and throw on non-200 status. A global `httpClient` and `log` are defined in `main.swift` and used directly by commands. `String` helpers include `maxMessageLengthChunks()` for splitting output to Discord's message length limit.
