//import Sword
//import cows
//
//extension Command where Trigger == Message {
//    static let vaca = Command(
//        run: { bot, message in
//            guard message.content.starts(with: "!vaca") else { return }
//
//            let components = message.content.components(separatedBy: " ")
//            let cow: String
//            if components.count > 1 {
//                let query = components
//                    .dropFirst()
//                    .joined(separator: " ")
//                    .lowercased()
//                cow = cows.allCows.filter { $0.lowercased().contains(query) }.randomElement() ?? cows.vaca()
//            } else {
//                cow = cows.vaca()
//            }
//
//            bot.send("""
//            ```
//            \(cow)
//            ```
//            """, to: message.channel.id)
//        }
//    )
//}
