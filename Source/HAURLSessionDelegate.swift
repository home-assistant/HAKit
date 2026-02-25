import Foundation

/// Protocol for providing certificate authentication for HAKit REST API calls
public protocol HACertificateProvider {
    /// Called when the server requests a client certificate (mTLS)
    /// - Parameters:
    ///   - challenge: The authentication challenge
    ///   - completionHandler: Handler to call with the authentication result
    func provideClientCertificate(
        for challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    )

    /// Called when the server's SSL certificate needs validation
    /// - Parameters:
    ///   - serverTrust: The server trust to evaluate
    ///   - host: The hostname being connected to
    ///   - completionHandler: Handler to call with the validation result
    func evaluateServerTrust(
        _ serverTrust: SecTrust,
        forHost host: String,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    )
}

/// URLSession delegate for HAKit REST API calls that supports custom certificate handling
///
/// This delegate handles both client certificate authentication (mTLS) and custom server
/// certificate validation through the `HACertificateProvider` protocol.
///
/// Example usage:
/// ```swift
/// struct MyCertificateProvider: HACertificateProvider {
///     func provideClientCertificate(for challenge: ...) {
///         // Provide client certificate from keychain
///     }
///
///     func evaluateServerTrust(_ serverTrust: ...) {
///         // Validate self-signed or custom CA certificates
///     }
/// }
///
/// let provider = MyCertificateProvider()
/// let delegate = HAURLSessionDelegate(certificateProvider: provider)
/// let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
/// let connection = HAKit.connection(configuration: config, urlSession: session)
/// ```
public class HAURLSessionDelegate: NSObject, URLSessionDelegate {
    private let certificateProvider: HACertificateProvider

    /// Initialize with a certificate provider
    /// - Parameter certificateProvider: The provider that handles certificate authentication
    public init(certificateProvider: HACertificateProvider) {
        self.certificateProvider = certificateProvider
        super.init()
    }
 
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodClientCertificate:
            certificateProvider.provideClientCertificate(
                for: challenge,
                completionHandler: completionHandler
            )

        case NSURLAuthenticationMethodServerTrust:
            if let serverTrust = challenge.protectionSpace.serverTrust {
                certificateProvider.evaluateServerTrust(
                    serverTrust,
                    forHost: challenge.protectionSpace.host,
                    completionHandler: completionHandler
                )
            } else {
                completionHandler(.performDefaultHandling, nil)
            }

        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
