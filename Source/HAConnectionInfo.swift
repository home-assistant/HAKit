import Foundation
import Starscream

/// Information for connecting to the server
public struct HAConnectionInfo: Equatable {
    /// Thrown if connection info was not able to be created
    enum CreationError: Error {
        /// The URL's host was empty, which would otherwise crash if used
        case emptyHostname
        /// The port provided exceeds the maximum allowed TCP port (2^16-1)
        case invalidPort
    }

    /// Create a connection info
    ///
    /// URLs are in the form of: https://url-to-hass:8123 and /api/websocket will be appended.
    ///
    /// - Parameter url: The url to connect to
    /// - Parameter userAgent: Optionally change the User-Agent to this
    /// - Throws: If the URL provided is invalid in some way, see `CreationError`
    public init(url: URL, userAgent: String? = nil) throws {
        try self.init(url: url, userAgent: userAgent, engine: nil)
    }

    /// Internally create a connection info with engine
    internal init(url: URL, userAgent: String?, engine: Engine?) throws {
        guard let host = url.host, !host.isEmpty else {
            throw CreationError.emptyHostname
        }

        guard (url.port ?? 80) <= UInt16.max else {
            throw CreationError.invalidPort
        }

        self.url = Self.sanitize(url)
        self.userAgent = userAgent
        self.engine = engine
    }

    /// The base URL for the WebSocket connection
    public var url: URL
    /// The URL used to connect to the WebSocket API
    public var webSocketURL: URL {
        url.appendingPathComponent("api/websocket")
    }

    /// The user agent to use in the connection
    public var userAgent: String?

    /// Used for dependency injection in tests
    internal var engine: Engine?

    /// Should this connection info take over an existing connection?
    ///
    /// - Parameter webSocket: The WebSocket to test
    /// - Returns: true if the connection should be replaced, false otherwise
    internal func shouldReplace(_ webSocket: WebSocket) -> Bool {
        webSocket.request.url.map(Self.sanitize) != Self.sanitize(url)
    }

    internal func request(url: URL) -> URLRequest {
        var request = URLRequest(url: url)

        if let userAgent = userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }

        if let host = url.host {
            if let port = url.port, port != 80, port != 443 {
                // URLSession behavior: omit optional port if 80 or 443
                // Starscream does the opposite, where it always includes port
                request.setValue("\(host):\(port)", forHTTPHeaderField: "Host")
            } else {
                request.setValue(host, forHTTPHeaderField: "Host")
            }
        }

        return request
    }

    internal func request(
        path: String,
        queryItems: [URLQueryItem]
    ) -> URLRequest {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        urlComponents.path += "/" + path

        if !queryItems.isEmpty {
            // providing an empty array will cause `?` to be added in all cases
            urlComponents.queryItems = (urlComponents.queryItems ?? []) + queryItems
        }

        return request(url: urlComponents.url!)
    }

    /// Create a new WebSocket connection
    /// - Returns: The newly-created WebSocket connection
    internal func webSocket() -> WebSocket {
        let request = self.request(url: webSocketURL)
        let webSocket: WebSocket

        if let engine = engine {
            webSocket = WebSocket(request: request, engine: engine)
        } else {
            webSocket = WebSocket(request: request)
        }

        return webSocket
    }

    /// Clean up the given URL
    /// - Parameter url: The raw URL
    /// - Returns: A URL with common issues removed
    private static func sanitize(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        for substring in [
            "/api/websocket",
            "/api",
        ] {
            if let range = components.path.range(of: substring) {
                components.path.removeSubrange(range)
            }
        }

        // We expect no extra trailing / in the
        while components.path.hasSuffix("/") {
            // remove any trailing /
            components.path.removeLast()
        }

        return components.url!
    }

    public static func == (lhs: HAConnectionInfo, rhs: HAConnectionInfo) -> Bool {
        lhs.url == rhs.url
    }
}
