import Foundation
import OSLog

enum AppLog {
    static let subsystem = "com.cryptotokenbar"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let websocket = Logger(subsystem: subsystem, category: "websocket")
    static let provider = Logger(subsystem: subsystem, category: "provider")
    static let screensaver = Logger(subsystem: subsystem, category: "screensaver")

    static func appendToFile(_ line: String, path: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fullLine = "[\(timestamp)] \(line)\n"

        guard let data = fullLine.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: path) {
            guard let handle = FileHandle(forWritingAtPath: path) else { return }
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }
}
