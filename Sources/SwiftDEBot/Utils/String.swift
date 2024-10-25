extension String: Error { }

extension String {
    var queryString: String? {
        self.components(separatedBy: " ")[1...]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func maxMessageLengthChunks(maxChars: Int = 2000) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""

        let words = self.components(separatedBy: " ")
        for word in words {
            if currentChunk.count + word.count + 1 > maxChars {
                // chunk is full
                chunks.append(currentChunk)
                currentChunk = ""
            }
            currentChunk += " " + word
        }
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        return chunks
    }
}
