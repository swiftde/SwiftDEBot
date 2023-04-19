extension String: Error { }

extension String {
    var queryString: String? {
        self.components(separatedBy: " ")[1...]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
