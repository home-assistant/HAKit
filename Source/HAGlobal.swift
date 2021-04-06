import Foundation

/// Global scoping of outward-facing dependencies used within the library
public enum HAGlobal {
    /// The log level
    public enum LogLevel {
        /// A log representing things like state transitions and connectivity changes
        case info
        /// A log representing an error condition
        case error
    }

    /// Verbose logging from the library; defaults to not doing anything
    public static var log: (LogLevel, String) -> Void = { _, _ in }
    /// Used to mutate date handling for reconnect retrying
    public static var date: () -> Date = Date.init
}
