import Foundation

public enum HAGlobal {
    /// Verbose logging from the library; defaults to not doing anything
    public static var log: (String) -> Void = { _ in }
    /// Used to mutate date handling for reconnect retrying
    public static var date: () -> Date = Date.init
}
