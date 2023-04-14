FROM swift:5.7 AS build
# RUN apt-get update && apt-get install -y libsodium-dev
# RUN update-ca-certificates --fresh

WORKDIR /app
COPY . ./
RUN swift build --configuration release

FROM swift:5.7-slim
WORKDIR /app
COPY --from=build /app/.build/release/SwiftDEBot .

CMD ["./SwiftDEBot"]
