import DiscordBM

protocol Command {
    func run(client: DiscordClient, message: Gateway.MessageCreate) async throws
}
