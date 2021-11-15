FROM swift:4 AS build
RUN apt-get update && apt-get install -y libsodium-dev

WORKDIR /app
COPY . ./
RUN swift build --configuration release

FROM swift:4
RUN update-ca-certificates --fresh
WORKDIR /app
COPY --from=build /app/.build/release/SwiftDEBot .

CMD ["./SwiftDEBot"]
