import Foundation

// Simple file logger for debugging. Writes to ~/ocrshot.log.
enum DebugLog {
    static let path = NSString(string: "~/ocrshot.log").expandingTildeInPath

    static func log(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        if let h = FileHandle(forWritingAtPath: path) {
            h.seekToEndOfFile()
            h.write(line.data(using: .utf8)!)
            h.closeFile()
        } else {
            try? line.data(using: .utf8)?.write(to: URL(fileURLWithPath: path))
        }
    }
}
