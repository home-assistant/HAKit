import Foundation
#if SWIFT_PACKAGE
import HAKit
#endif

public extension HAConnectionConfiguration {
    /// A basic, fake configuration that is always successful.
    /// This is available to be modified at will; nothing depends on the values provided.
    static var fake = HAConnectionConfiguration(
        connectionInfo: { () -> HAConnectionInfo? in
            try? .init(url: URL(string: "http://127.0.0.1:8123")!)
        }, fetchAuthToken: { completion in
            completion(.success("fake_auth_token"))
        }
    )
}

/// A mock cancellable
///
/// This is provided in all requests/subscriptions to `HAMockConnection`.
public class HAMockCancellable: HACancellable {
    /// The handler to invoke when cancelled; reset to nothing when called
    public var handler: () -> Void
    /// Create an instance with a handler
    /// - Parameter handler: The handler to invoke for cancel
    public init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    /// Whether the cancel method was invoked
    public var wasCancelled: Bool = false

    /// Marks that the cancellable was cancelled, and adds the result to the `HAMockConnection`.
    public func cancel() {
        wasCancelled = true
        handler()
        handler = {}
    }
}

/// Mock connection
///
/// Provides basic scaffolding to test usage of the library.
public class HAMockConnection: HAConnection {
    // MARK: - Mock Handling

    /// A pending request
    public struct PendingRequest {
        /// The request provided, or the underlying one for typed requests
        public var request: HARequest
        /// The cancellable provided to the initial request
        public var cancellable: HAMockCancellable
        /// The completion provided for the request -- this may be one that maps to a typed version
        public var completion: RequestCompletion
    }

    /// All pending requests
    public var pendingRequests = [PendingRequest]()
    /// A pending subscription
    public struct PendingSubscription {
        /// The request provided, or the underlying one for typed subscriptions
        public var request: HARequest
        /// The cancellable provided to the initial subscription
        public var cancellable: HAMockCancellable
        /// The initiated handler if provided, otherwise a noop one
        public var initiated: SubscriptionInitiatedHandler
        /// The handler provided for the subscription -- this may be one that maps to a typed version
        public var handler: SubscriptionHandler
    }

    /// All pending subscriptions
    public var pendingSubscriptions = [PendingSubscription]()
    /// All requests whose cancellable was invoked
    public var cancelledRequests = [HARequest]()
    /// All subscription requests whose cancellable was invoked
    public var cancelledSubscriptions = [HARequest]()
    /// Whether to turn to 'connecting' when a 'send' or 'subscribe' occurs when 'disconnected'
    public var automaticallyTransitionToConnecting = true

    // MARK: - Mock Implementation

    public weak var delegate: HAConnectionDelegate?
    public lazy var caches: HACachesContainer = .init(connection: self)

    public var configuration: HAConnectionConfiguration
    public init(configuration: HAConnectionConfiguration = .fake) {
        self.configuration = configuration
    }

    public private(set) var state: HAConnectionState = .disconnected(reason: .disconnected) {
        didSet {
            // matching async behavior of HAConnectionImpl
            callbackQueue.async { [self, state] in
                delegate?.connection(self, didTransitionTo: state)
                NotificationCenter.default.post(name: HAConnectionState.didTransitionToStateNotification, object: self)
            }
        }
    }

    public func setState(_ state: HAConnectionState, waitForQueue: Bool = true) {
        self.state = state
        if waitForQueue {
            waitForCallbackQueue()
        }
    }

    public var callbackQueue: DispatchQueue = .main

    public func connect() {
        if configuration.connectionInfo() == nil {
            state = .disconnected(reason: .disconnected)
        } else {
            state = .connecting
            state = .authenticating
            configuration.fetchAuthToken { [self] result in
                switch result {
                case .success:
                    state = .ready(version: "1.0-mock")
                case let .failure(error):
                    state = .disconnected(reason: .waitingToReconnect(
                        lastError: error,
                        atLatest: Date(timeIntervalSinceNow: 1000),
                        retryCount: 1
                    ))
                }
            }
        }
    }

    private func connectForRequest() {
        guard automaticallyTransitionToConnecting, case .disconnected = state else {
            return
        }

        state = .connecting
    }

    public func disconnect() {
        state = .disconnected(reason: .disconnected)
    }

    public func send(_ request: HARequest, completion: @escaping RequestCompletion) -> HACancellable {
        let cancellable = HAMockCancellable { [self] in cancelledRequests.append(request) }
        pendingRequests.append(.init(request: request, cancellable: cancellable, completion: completion))
        connectForRequest()
        return cancellable
    }

    public func send<T: HADataDecodable>(
        _ request: HATypedRequest<T>,
        completion: @escaping (Result<T, HAError>) -> Void
    ) -> HACancellable {
        send(request.request, completion: { dataResult in
            switch dataResult {
            case let .success(data):
                do {
                    completion(.success(try T(data: data)))
                } catch {
                    completion(.failure(.underlying(error as NSError)))
                }
            case let .failure(error):
                completion(.failure(error))
            }
        })
    }

    public func subscribe(to request: HARequest, handler: @escaping SubscriptionHandler) -> HACancellable {
        subscribe(to: request, initiated: { _ in }, handler: handler)
    }

    public func subscribe(
        to request: HARequest,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        let cancellable = HAMockCancellable { [self] in cancelledSubscriptions.append(request) }
        pendingSubscriptions.append(.init(
            request: request,
            cancellable: cancellable,
            initiated: initiated,
            handler: handler
        ))
        connectForRequest()
        return cancellable
    }

    public func subscribe<T: HADataDecodable>(
        to request: HATypedSubscription<T>,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        subscribe(to: request, initiated: { _ in }, handler: handler)
    }

    public func subscribe<T: HADataDecodable>(
        to request: HATypedSubscription<T>,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        subscribe(to: request.request, initiated: initiated, handler: { cancellable, data in
            do {
                handler(cancellable, try T(data: data))
            } catch {}
        })
    }

    public func waitForCallbackQueue() {
        precondition(Thread.isMainThread)
        let runLoopMode = CFRunLoopMode.defaultMode

        var context = CFRunLoopSourceContext()
        let runLoop = CFRunLoopGetCurrent()
        let runLoopSource = CFRunLoopSourceCreate(nil, 0, &context)
        CFRunLoopAddSource(runLoop, runLoopSource, runLoopMode)

        var hasCalled: Int32 = 0

        let stop = {
            OSAtomicCompareAndSwap32(0, 1, &hasCalled)
            CFRunLoopStop(runLoop)
        }

        callbackQueue.async(execute: stop)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5), execute: stop)

        while hasCalled == 0 {
            CFRunLoopRunInMode(runLoopMode, 1.0, false)
        }
    }
}
