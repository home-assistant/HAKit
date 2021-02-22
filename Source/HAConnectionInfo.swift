import Foundation

/// Information for connecting to the server
public struct HAConnectionInfo {
    public init(url: URL) {
        self.url = url
    }

    public var url: URL
}
