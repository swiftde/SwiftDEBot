import Sword

struct Command<Trigger> {
    var run: (Sword, Trigger) -> Void
}
