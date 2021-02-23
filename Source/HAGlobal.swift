import Foundation

public enum HAGlobal {
    public static var log: (String) -> Void = { print($0) }
    public static var date: () -> Date = Date.init
}
