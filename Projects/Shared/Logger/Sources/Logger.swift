import Foundation
import OSLog
import SharedUtils

public final class Logger: @unchecked Sendable {
    public static let shared = Logger(
        subsystem: AppInfo.bundleID
    )

    private let subsystem: String
    private let lock = NSLock()
    private var loggers: [LogCategory: os.Logger] = [:]

    init(subsystem: String) {
        self.subsystem = subsystem
    }

    public func debug(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        includeCallSite: Bool = true,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            message(),
            level: .debug,
            category: category,
            includeCallSite: includeCallSite,
            site: CallSite(file: file, function: function, line: line)
        )
    }

    public func info(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        includeCallSite: Bool = true,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            message(),
            level: .info,
            category: category,
            includeCallSite: includeCallSite,
            site: CallSite(file: file, function: function, line: line)
        )
    }

    public func warning(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        includeCallSite: Bool = true,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            message(),
            level: .warning,
            category: category,
            includeCallSite: includeCallSite,
            site: CallSite(file: file, function: function, line: line)
        )
    }

    public func error(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        includeCallSite: Bool = true,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            message(),
            level: .error,
            category: category,
            includeCallSite: includeCallSite,
            site: CallSite(file: file, function: function, line: line)
        )
    }

    private func log(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        includeCallSite: Bool,
        site: CallSite
    ) {
        #if DEBUG
        let composed: String
        if includeCallSite {
            let fileName = site.file.split(separator: "/").last.map(String.init) ?? site.file
            composed =
                "[\(category.displayName)] [\(fileName):\(site.line)] \(site.function) - \(message)"
        } else {
            composed = message
        }
        let logger = osLogger(for: category)
        logger.log(level: level.osLogType, "\(composed, privacy: .public)")
        #endif
    }

    private func osLogger(for category: LogCategory) -> os.Logger {
        lock.lock()
        defer { lock.unlock() }

        if let existing = loggers[category] {
            return existing
        }

        let created = os.Logger(subsystem: subsystem, category: category.rawValue)
        loggers[category] = created
        return created
    }

    private struct CallSite {
        let file: String
        let function: String
        let line: Int
    }
}
