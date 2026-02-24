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

    /// Certificate validation handler
    public typealias EvaluateCertificate = (SecTrust, (Result<Void, Error>) -> Void) -> Void

    #if !os(watchOS)
    /// Client identity provider for mTLS
    public typealias ClientIdentityProvider = () -> SecIdentity?
    #endif

    #if !os(watchOS)
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
    #else
    /// Create a connection info
    public init(
        url: URL,
        userAgent: String? = nil,
        evaluateCertificate: EvaluateCertificate? = nil
    ) throws {
        try self.init(
            url: url,
            userAgent: userAgent,
            evaluateCertificate: evaluateCertificate,
            engine: nil
        )
    }
    #endif

    #if !os(watchOS)
    /// Internally create a connection info with engine
    internal init(
        url: URL,
        userAgent: String?,
        evaluateCertificate: EvaluateCertificate?,
        clientIdentity: ClientIdentityProvider?,
        engine: Engine?
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
    #else
    /// Internally create a connection info with engine
    internal init(
        url: URL,
        userAgent: String?,
        evaluateCertificate: EvaluateCertificate?,
        engine: Engine?
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
    }
    #endif

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

    /// Used to validate certificate, if provided
    internal var evaluateCertificate: EvaluateCertificate?

    #if !os(watchOS)
    /// Used to provide client identity (SecIdentity) for mTLS
    internal var clientIdentity: ClientIdentityProvider?
    #endif

    /// Should this connection info take over an existing connection?
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
    internal func webSocket() -> WebSocket {
        let request = self.request(url: webSocketURL)
        let webSocket: WebSocket

        #if !os(watchOS)
        if let engine = engine {
            webSocket = WebSocket(request: request, engine: engine)
        } else if let clientIdentity = clientIdentity {
            // Use FoundationTransport with stream configuration for mTLS
            let hasCertEval = evaluateCertificate != nil
            let transport = FoundationTransport(
                streamConfiguration: Self.makeStreamConfiguration(
                    clientIdentity: clientIdentity,
                    disableCertificateChainValidation: hasCertEval
                )
            )
            let pinning = evaluateCertificate.flatMap { HAStarscreamCertificatePinningImpl(evaluateCertificate: $0) }
            let engine = WSEngine(transport: transport, certPinner: pinning)
            webSocket = WebSocket(request: request, engine: engine)
        } else {
            let pinning = evaluateCertificate.flatMap { HAStarscreamCertificatePinningImpl(evaluateCertificate: $0) }
            webSocket = WebSocket(request: request, certPinner: pinning, compressionHandler: WSCompression())
        }
        #else
        if let engine = engine {
            webSocket = WebSocket(request: request, engine: engine)
        } else {
            let pinning = evaluateCertificate.flatMap { HAStarscreamCertificatePinningImpl(evaluateCertificate: $0) }
            webSocket = WebSocket(request: request, certPinner: pinning, compressionHandler: WSCompression())
        }
        #endif

        return webSocket
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

    #if !os(watchOS)
    /// Builds the SSL stream settings dictionary for client certificate configuration.
    /// - Parameters:
    ///   - certificateArray: Array of `SecIdentity`/`SecCertificate` for `kCFStreamSSLCertificates`, or nil
    ///   - disableCertificateChainValidation: Pass true when custom certificate evaluation is in use
    /// - Returns: SSL settings dictionary; empty if no configuration is needed
    internal static func makeSSLSettings(
        certificateArray: CFArray?,
        disableCertificateChainValidation: Bool
    ) -> [String: Any] {
        var settings: [String: Any] = [:]
        if let certificateArray {
            settings[kCFStreamSSLCertificates as String] = certificateArray
        }
        if disableCertificateChainValidation {
            settings[kCFStreamSSLValidatesCertificateChain as String] = false
        }
        return settings
    }

    /// Returns a stream configuration closure suitable for use with `FoundationTransport`.
    /// - Parameters:
    ///   - clientIdentity: Provider for the client identity used in mTLS
    ///   - disableCertificateChainValidation: Pass true when custom certificate evaluation is in use
    /// - Returns: A closure that configures SSL settings on the given streams
    internal static func makeStreamConfiguration(
        clientIdentity: @escaping ClientIdentityProvider,
        disableCertificateChainValidation: Bool
    ) -> (InputStream, OutputStream) -> Void {
        { inStream, outStream in
            let certificateArray = clientIdentity().map { [$0] as CFArray }
            let sslSettings = makeSSLSettings(
                certificateArray: certificateArray,
                disableCertificateChainValidation: disableCertificateChainValidation
            )
            if !sslSettings.isEmpty {
                CFReadStreamSetProperty(
                    inStream,
                    CFStreamPropertyKey(rawValue: kCFStreamPropertySSLSettings),
                    sslSettings as CFTypeRef
                )
                CFWriteStreamSetProperty(
                    outStream,
                    CFStreamPropertyKey(rawValue: kCFStreamPropertySSLSettings),
                    sslSettings as CFTypeRef
                )
            }
        }
    }
    #endif

    public static func == (lhs: HAConnectionInfo, rhs: HAConnectionInfo) -> Bool {
        lhs.url == rhs.url
    }
}
