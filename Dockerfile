# Must match the Swift version in nixpkgs; `nix flake check` verifies this.
ARG SWIFT_VERSION=6.2.4

FROM swift:${SWIFT_VERSION} AS build

WORKDIR /app
COPY . ./
RUN swift build --configuration release

FROM swift:${SWIFT_VERSION}-slim
WORKDIR /app
COPY --from=build /app/.build/release/SwiftDEBot .

CMD ["./SwiftDEBot"]
