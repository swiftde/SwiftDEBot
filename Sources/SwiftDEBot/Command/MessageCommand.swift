import Sword

struct MessageCommand {
    var shouldRun: (Message) -> Bool
    var run: (Sword, Message) throws -> Void
}
