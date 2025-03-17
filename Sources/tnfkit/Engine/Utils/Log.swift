// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import os

public final class Log {

    private enum Level: String {
        case debug = "🔍 DEBUG"
        case info = "ℹ️ INFO"
        case warning = "⚠️ WARNING"
        case error = "❌ ERROR"

        var color: String {
            switch self {
            case .debug: return "\u{001B}[34m"
            case .info: return "\u{001B}[32m"
            case .warning: return "\u{001B}[33m"
            case .error: return "\u{001B}[31m"
            }
        }

    }

    //NOTE: Change this function if you want to change how the logged message looks
    private static func formatMessage(
        _ level: Level,
        _ message: Any,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> String {
        var components: [String] = []

        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        components.append("[\(formatter.string(from: date))]")

        components.append(level.rawValue)

        let filename = (file as NSString).lastPathComponent
        components.append("[\(filename):\(line)]")

        components.append("\(message)")
        return level.color + components.joined(separator: " ") + "\u{001B}[0m"
    }

    private static func isRunningInXcodeConsole() -> Bool {
        return ProcessInfo.processInfo.environment["TERM_PROGRAM"] == nil

    }

    public static func debug(
        _ message: Any, file: String = #file, function: String = #function, line: Int = #line
    ) {
        if isRunningInXcodeConsole() {
            os_log(
                "🔍 DEBUG [%{public}s:%d] %{public}@", type: .debug,
                (file as NSString).lastPathComponent, line, "\(message)")
        } else {
            print(formatMessage(.debug, message, file: file, function: function, line: line))
        }
    }

    public static func info(
        _ message: Any, file: String = #file, function: String = #function, line: Int = #line
    ) {
        if isRunningInXcodeConsole() {
            os_log(
                "ℹ️ INFO [%{public}s:%d] %{public}@", type: .info,
                (file as NSString).lastPathComponent, line, "\(message)")
        } else {
            print(formatMessage(.info, message, file: file, function: function, line: line))
        }
    }

    public static func warning(
        _ message: Any, file: String = #file, function: String = #function, line: Int = #line
    ) {
        if isRunningInXcodeConsole() {
            os_log(
                "⚠️ WARNING [%{public}s:%d] %{public}@", type: .default,
                (file as NSString).lastPathComponent, line, "\(message)")
        } else {
            print(formatMessage(.warning, message, file: file, function: function, line: line))
        }
    }

    public static func error(
        _ message: Any, file: String = #file, function: String = #function, line: Int = #line
    ) {
        if isRunningInXcodeConsole() {
            os_log(
                "❌ ERROR [%{public}s:%d] %{public}@", type: .error,
                (file as NSString).lastPathComponent, line, "\(message)")
        } else {
            print(formatMessage(.error, message, file: file, function: function, line: line))
        }
    }

}
