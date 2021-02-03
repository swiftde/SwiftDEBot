import Foundation

func getCurrentProjectVersion() throws -> String? {
    let git = Process()
    git.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    git.arguments = ["describe", "--abbrev=0", "--tags"]
    let output = Pipe()
    git.standardOutput = output
    try git.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

let version = try! getCurrentProjectVersion() ?? "unknown"

let fileManager = FileManager.default
let pathToVersion = fileManager.currentDirectoryPath + "/Sources/SwiftDEBot/Utils/Version.swift"

let versionDecl = #"""
// This file is automatically updated on running `make update-version`. Please don't check any changes into git.
let VERSION = "\#(version)"
"""#
try! versionDecl.write(toFile: pathToVersion, atomically: false, encoding: .utf8)
