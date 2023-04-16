FROM swift:5.7 AS build

WORKDIR /app
COPY . ./
RUN swift build --configuration release

FROM swift:5.7-slim
WORKDIR /app
COPY --from=build /app/.build/release/SwiftDEBot .

CMD ["./SwiftDEBot"]
