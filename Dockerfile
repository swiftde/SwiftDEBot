FROM swift:6.2.4 AS build

WORKDIR /app
COPY . ./
RUN swift build --configuration release

FROM swift:6.2.4-slim
WORKDIR /app
COPY --from=build /app/.build/release/SwiftDEBot .

CMD ["./SwiftDEBot"]
