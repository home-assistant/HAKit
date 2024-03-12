import Foundation
import Starscream

// NOTE: see HAConnection.swift for how to access these types

internal class HAConnectionImpl: HAConnection {
    public weak var delegate: HAConnectionDelegate?
    public var configuration: HAConnectionConfiguration

    public var callbackQueue: DispatchQueue = .main
    internal var workQueue = DispatchQueue(
        label: "hakit-work-queue",
        autoreleaseFrequency: .workItem,
        target: .global()
    )

    public var state: HAConnectionState {
        switch responseController.phase {
        case .disconnected:
            if connection == nil {
                return .disconnected(reason: reconnectManager.reason)
            } else {
                return .connecting
            }
        case .auth:
            return .authenticating
        case let .command(version):
            return .ready(version: version)
        }
    }

    internal func notifyState() {
        callbackQueue.async { [self, state] in
            delegate?.connection(self, didTransitionTo: state)
            NotificationCenter.default.post(
                name: HAConnectionState.didTransitionToStateNotification,
                object: self
            )
        }
    }

    internal private(set) var connection: WebSocket? {
        didSet {
            connection?.delegate = self

            if oldValue !== connection {
                oldValue?.disconnect(closeCode: CloseCode.goingAway.rawValue)
                responseController.reset()
                connection?.connect()
            }
        }
    }

    internal enum ConnectError: Error {
        case noConnectionInfo
    }

    let requestController: HARequestController
    let responseController: HAResponseController
    let reconnectManager: HAReconnectManager
    let urlSession: URLSession
    var connectAutomatically: Bool
    var hasSetupResubscribeEvents = HAProtected<Bool>(value: false)
    private(set) lazy var caches: HACachesContainer = .init(connection: self)

    init(
        configuration: HAConnectionConfiguration,
        requestController: HARequestController = HARequestControllerImpl(),
        responseController: HAResponseController = HAResponseControllerImpl(),
        reconnectManager: HAReconnectManager = HAReconnectManagerImpl(),
        urlSession: URLSession = .init(configuration: .ephemeral),
        connectAutomatically: Bool = false
    ) {
        self.configuration = configuration
        self.requestController = requestController
        self.responseController = responseController
        self.reconnectManager = reconnectManager
        self.urlSession = urlSession
        self.connectAutomatically = connectAutomatically

        requestController.delegate = self
        requestController.workQueue = workQueue
        responseController.delegate = self
        responseController.workQueue = workQueue
        reconnectManager.delegate = self
    }

    private func setupResubscribeEvents() {
        let events = hasSetupResubscribeEvents.mutate { value -> [HAEventType] in
            guard !value else { return [] }

            value = true
            return requestController.retrySubscriptionsEvents
        }

        for event in events {
            _ = commonSubscribe(
                to: .events(event),
                allowConnecting: false,
                initiated: nil,
                handler: { [requestController] _, _ in requestController.retrySubscriptions() }
            )
        }
    }

    // MARK: - Connection Handling

    public func connect() {
        performConnectionChange { [self] in
            connect(resettingState: true)
        }
    }

    public func disconnect() {
        performConnectionChange { [self] in
            disconnect(permanently: true, error: nil)
        }
    }

    private func connectAutomaticallyIfNeeded() {
        guard connectAutomatically, case .disconnected = state else { return }
        connect()
    }

    func performConnectionChange(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    func connect(resettingState: Bool) {
        precondition(Thread.isMainThread)

        guard let connectionInfo = configuration.connectionInfo() else {
            disconnect(permanently: false, error: ConnectError.noConnectionInfo)
            return
        }

        setupResubscribeEvents()

        let connection: WebSocket = {
            guard let existing = self.connection else {
                return connectionInfo.webSocket()
            }

            guard connectionInfo.shouldReplace(existing) else {
                return existing
            }

            return connectionInfo.webSocket()
        }()

        guard connection !== self.connection else {
            return
        }

        if resettingState {
            reconnectManager.didStartInitialConnect()
        }

        let oldState = state
        HAGlobal.log(.info, "connecting using \(connectionInfo)")
        self.connection = connection
        if state != oldState {
            notifyState()
        }
    }

    func disconnect(permanently: Bool, error: Error?) {
        precondition(Thread.isMainThread)

        HAGlobal.log(.info, "disconnecting; permanently: \(permanently), error: \(String(describing: error))")

        connection?.delegate = nil
        connection?.disconnect(closeCode: CloseCode.goingAway.rawValue)
        connection = nil

        if permanently {
            reconnectManager.didDisconnectPermanently()
        } else {
            reconnectManager.didDisconnectTemporarily(error: error)
        }

        notifyState()
    }

    // MARK: - Sending

    @discardableResult
    public func send(
        _ request: HARequest,
        completion: @escaping RequestCompletion
    ) -> HACancellable {
        let invocation = HARequestInvocationSingle(request: request, completion: completion)
        requestController.add(invocation)
        defer { connectAutomaticallyIfNeeded() }
        return HACancellableImpl { [requestController] in
            requestController.cancel(invocation)
        }
    }

    @discardableResult
    public func send<T>(
        _ request: HATypedRequest<T>,
        completion: @escaping (Result<T, HAError>) -> Void
    ) -> HACancellable {
        send(request.request) { [workQueue, callbackQueue] result in
            workQueue.async {
                let converted: Result<T, HAError> = result.flatMap { data in
                    do {
                        let updated = try T(data: data)
                        return .success(updated)
                    } catch {
                        return .failure(.underlying(error as NSError))
                    }
                }

                callbackQueue.async {
                    completion(converted)
                }
            }
        }
    }

    // MARK: Subscribing

    private func commonSubscribe(
        to request: HARequest,
        allowConnecting: Bool = true,
        initiated: SubscriptionInitiatedHandler?,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        let sub = HARequestInvocationSubscription(request: request, initiated: initiated, handler: handler)
        requestController.add(sub)
        defer {
            if allowConnecting {
                connectAutomaticallyIfNeeded()
            }
        }
        return HACancellableImpl { [requestController] in
            requestController.cancel(sub)
        }
    }

    private func commonSubscribe<T>(
        to request: HATypedSubscription<T>,
        allowConnecting: Bool = true,
        initiated: SubscriptionInitiatedHandler?,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        commonSubscribe(
            to: request.request,
            allowConnecting: allowConnecting,
            initiated: initiated,
            handler: { [workQueue, callbackQueue] token, data in
                workQueue.async {
                    do {
                        let value = try T(data: data)
                        callbackQueue.async {
                            handler(token, value)
                        }
                    } catch {
                        HAGlobal.log(.info, "couldn't parse data \(error)")
                    }
                }
            }
        )
    }

    @discardableResult
    public func subscribe(
        to request: HARequest,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        commonSubscribe(to: request, initiated: nil, handler: handler)
    }

    @discardableResult
    public func subscribe(
        to request: HARequest,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        commonSubscribe(to: request, initiated: initiated, handler: handler)
    }

    @discardableResult
    public func subscribe<T>(
        to request: HATypedSubscription<T>,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        commonSubscribe(to: request, initiated: nil, handler: handler)
    }

    @discardableResult
    public func subscribe<T>(
        to request: HATypedSubscription<T>,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        commonSubscribe(to: request, initiated: initiated, handler: handler)
    }

    // MARK: - Write

    public func write(_ dataRequest: HARequest) {
        if case .data = dataRequest.type {
            defer { connectAutomaticallyIfNeeded() }
            let invocation = HARequestInvocationSingle(request: dataRequest) { _ in }
            requestController.add(invocation)
        } else {
            HAGlobal.log(.error, "Write operation can only be executed by data HARequest")
        }
    }
}

// MARK: -

extension HAConnectionImpl {
    private static func data(from dictionary: [String: Any]) -> Data {
        // the only cases where JSONSerialization appears to fail are cases where it throws exceptions too
        // this is bad API from Apple that I don't feel like dealing with :grimace:

        // swiftlint:disable:next force_try
        try! JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
    }

    private func sendWebSocket(
        identifier: HARequestIdentifier?,
        request: HARequest,
        command: String
    ) {
        workQueue.async { [connection] in
            var dictionary = request.data
            if let identifier = identifier {
                dictionary["id"] = identifier.rawValue
            }
            dictionary["type"] = command

            let string = String(data: Self.data(from: dictionary), encoding: .utf8)!

            if request.type == .auth {
                HAGlobal.log(.info, "Sending: (auth)")
            } else {
                HAGlobal.log(.info, "Sending: \(string)")
            }

            connection?.write(string: string)
        }
    }

    private func sendRest(
        identifier: HARequestIdentifier,
        request: HARequest,
        method: HAHTTPMethod,
        command: String
    ) {
        guard let connectionInfo = configuration.connectionInfo() else {
            responseController.didReceive(for: identifier, response: .failure(ConnectError.noConnectionInfo))
            return
        }

        configuration.fetchAuthToken { [self] result in
            switch result {
            case let .success(bearerToken):
                var httpRequest = connectionInfo.request(path: "api/" + command, queryItems: request.queryItems)
                httpRequest.httpMethod = method.rawValue
                httpRequest.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
                httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

                if method != .get, !request.data.isEmpty {
                    httpRequest.httpBody = Self.data(from: request.data)
                }

                let task = urlSession.dataTask(with: httpRequest) { [self] data, response, error in
                    if let response = response {
                        responseController.didReceive(
                            for: identifier,
                            // This badly-typed API will always return HTTPURLResponses to http/https endpoints.
                            // swiftlint:disable:next force_cast
                            response: .success((response as! HTTPURLResponse, data))
                        )
                    } else {
                        responseController.didReceive(for: identifier, response: .failure(error!))
                    }
                }

                let loggableBody: String

                if let body = httpRequest.httpBody {
                    loggableBody = String(data: body, encoding: .utf8) ?? "(undecodable)"
                } else {
                    loggableBody = ""
                }

                HAGlobal.log(.info, "Sending: \(identifier) \(method.rawValue) /api/\(command) \(loggableBody)")

                task.resume()
            case let .failure(error):
                responseController.didReceive(for: identifier, response: .failure(error))
            }
        }
    }

    private func sendWrite(_ data: Data) {
        workQueue.async { [connection] in
            connection?.write(data: data)
        }
    }

    func sendRaw(
        identifier: HARequestIdentifier?,
        request: HARequest
    ) {
        switch request.type {
        case let .webSocket(command):
            sendWebSocket(identifier: identifier, request: request, command: command)
        case let .rest(method, command):
            sendRest(identifier: identifier!, request: request, method: method, command: command)
        case let .data(data):
            sendWrite(data)
        }
    }
}

extension HAConnectionImpl: HAReconnectManagerDelegate {
    func reconnectManagerWantsReconnection(_ manager: HAReconnectManager) {
        connect(resettingState: false)
    }

    func reconnect(_ manager: HAReconnectManager, wantsDisconnectFor error: Error) {
        disconnect(permanently: false, error: error)
    }

    func reconnectManager(
        _ manager: HAReconnectManager,
        pingWithCompletion handler: @escaping (Result<Void, Error>) -> Void
    ) -> HACancellable {
        send(.init(type: .ping, data: [:])) { result in
            DispatchQueue.main.async {
                handler(result.map { _ in () }.mapError { $0 })
            }
        }
    }
}
