FROM swift:4 AS build
RUN apt-get update && apt-get install -y libsodium-dev

WORKDIR /app
COPY . ./
RUN make build

# FROM swift:5.3-slim
FROM swift:4
WORKDIR /app
COPY --from=build /app/.build/release/SwiftDEBot .

CMD ["./SwiftDEBot"]
