import Foundation

/// Information for connecting to the server
public struct HAConnectionInfo: Equatable {
    /// Thrown if connection info was not able to be created
    enum CreationError: Error {
        /// The URL's host was empty, which would otherwise crash if used
        case emptyHostname
        /// The port provided exceeds the maximum allowed TCP port (2^16-1)
        case invalidPort
    }

    /// Certificate validation handler
    public typealias EvaluateCertificate = (SecTrust, (Result<Void, Error>) -> Void) -> Void

    /// Client identity provider for mTLS
    public typealias ClientIdentityProvider = () -> SecIdentity?

    /// Create a connection info
    public init(
        url: URL,
        userAgent: String? = nil,
        evaluateCertificate: EvaluateCertificate? = nil,
        clientIdentity: ClientIdentityProvider? = nil
    ) throws {
        try self.init(
            url: url,
            userAgent: userAgent,
            evaluateCertificate: evaluateCertificate,
            clientIdentity: clientIdentity,
            engine: nil
        )
    }

    /// Internally create a connection info with engine
    internal init(
        url: URL,
        userAgent: String?,
        evaluateCertificate: EvaluateCertificate?,
        clientIdentity: ClientIdentityProvider?,
        engine: HAWebSocketEngine?
    ) throws {
        guard let host = url.host, !host.isEmpty else {
            throw CreationError.emptyHostname
        }

        guard (url.port ?? 80) <= UInt16.max else {
            throw CreationError.invalidPort
        }

        self.url = Self.sanitize(url)
        self.userAgent = userAgent
        self.engine = engine
        self.evaluateCertificate = evaluateCertificate
        self.clientIdentity = clientIdentity
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
    internal var engine: HAWebSocketEngine?

    /// Used to validate certificate, if provided
    internal var evaluateCertificate: EvaluateCertificate?

    /// Used to provide client identity (SecIdentity) for mTLS
    internal var clientIdentity: ClientIdentityProvider?

    /// Should this connection info take over an existing connection?
    internal func shouldReplace(_ webSocket: HAWebSocket) -> Bool {
        webSocket.request.url.map(Self.sanitize) != Self.sanitize(url)
    }

    internal func request(url: URL) -> URLRequest {
        var request = URLRequest(url: url)

        if let userAgent = userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }

        if let host = url.host {
            if let port = url.port, port != 80, port != 443 {
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
            urlComponents.queryItems = (urlComponents.queryItems ?? []) + queryItems
        }

        return request(url: urlComponents.url!)
    }

    /// Create a new WebSocket connection
    internal func webSocket() -> HAWebSocket {
        let request = self.request(url: webSocketURL)

        // Every connection uses `URLSessionWebSocketTask`. The URL Loading System handles server
        // trust evaluation and the mTLS client-identity challenge through the engine's
        // authentication handler, so a single path covers all cases.
        let engine = engine ?? HAURLSessionWebSocketEngine(
            clientIdentity: clientIdentity,
            evaluateCertificate: evaluateCertificate
        )

        return HAWebSocket(request: request, engine: engine)
    }

    private static func sanitize(_ url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        for substring in [
            "/api/websocket",
            "/api",
        ] {
            if let range = components.path.range(of: substring) {
                components.path.removeSubrange(range)
            }
        }

        while components.path.hasSuffix("/") {
            components.path.removeLast()
        }

        return components.url!
    }

    public static func == (lhs: HAConnectionInfo, rhs: HAConnectionInfo) -> Bool {
        lhs.url == rhs.url
    }
}
