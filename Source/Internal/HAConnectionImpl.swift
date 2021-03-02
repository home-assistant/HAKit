import Foundation
import Starscream

// NOTE: see HAConnection.swift for how to access these types

internal class HAConnectionImpl: HAConnectionProtocol {
    public weak var delegate: HAConnectionDelegate?
    public var configuration: HAConnectionConfiguration

    public var callbackQueue: DispatchQueue = .main

    private var lastDisconnectError: HAError?
    public var state: HAConnectionState {
        switch responseController.phase {
        case .disconnected:
            return .disconnected(reason: reconnectManager.reason)
        case .auth:
            return .connecting
        case let .command(version):
            return .ready(version: version)
        }
    }

    internal func notifyState() {
        delegate?.connection(self, didTransitionTo: state)
        NotificationCenter.default.post(
            name: HAConnection.didTransitionToStateNotification,
            object: self
        )
    }

    internal private(set) var connection: WebSocket? {
        didSet {
            connection?.delegate = self

            if oldValue !== connection {
                oldValue?.disconnect(closeCode: CloseCode.goingAway.rawValue)
                responseController.reset()
            }
        }
    }

    internal enum ConnectError: Error {
        case noConnectionInfo
    }

    let requestController: HARequestController
    let responseController: HAResponseController
    let reconnectManager: HAReconnectManager

    required convenience init(configuration: HAConnectionConfiguration) {
        self.init(
            configuration: configuration,
            requestController: HARequestControllerImpl(),
            responseController: HAResponseControllerImpl(),
            reconnectManager: HAReconnectManagerImpl()
        )
    }

    init(
        configuration: HAConnectionConfiguration,
        requestController: HARequestController,
        responseController: HAResponseController,
        reconnectManager: HAReconnectManager
    ) {
        self.configuration = configuration
        self.requestController = requestController
        self.responseController = responseController
        self.reconnectManager = reconnectManager

        requestController.delegate = self
        responseController.delegate = self
        reconnectManager.delegate = self
    }

    // MARK: - Connection Handling

    public func connect() {
        connect(resettingState: true)
    }

    public func disconnect() {
        disconnect(permanently: true, error: nil)
    }

    func connect(resettingState: Bool) {
        guard let connectionInfo = configuration.connectionInfo() else {
            disconnect(permanently: false, error: ConnectError.noConnectionInfo)
            return
        }

        let connection: WebSocket = {
            guard let existing = self.connection else {
                return connectionInfo.webSocket()
            }

            guard connectionInfo.shouldReplace(existing) else {
                return existing
            }

            return connectionInfo.webSocket()
        }()

        if resettingState {
            reconnectManager.didStartInitialConnect()
        }

        self.connection = connection
        connection.connect()
    }

    func disconnect(permanently: Bool, error: Error?) {
        if permanently {
            reconnectManager.didDisconnectPermanently()
        } else {
            reconnectManager.didDisconnectTemporarily(error: error)
        }

        connection?.delegate = nil
        connection?.disconnect(closeCode: CloseCode.goingAway.rawValue)
        connection = nil

        notifyState()
    }

    // MARK: - Sending

    @discardableResult
    public func send(
        _ request: HARequest,
        completion: @escaping RequestCompletion
    ) -> HACancellable {
        let invocation = HARequestInvocationSingle(request: request, completion: completion)
        requestController.add(invocation, completion: {})
        return HACancellableImpl { [requestController] in
            requestController.cancel(invocation, completion: {})
        }
    }

    @discardableResult
    public func send<T>(
        _ request: HATypedRequest<T>,
        completion: @escaping (Result<T, HAError>) -> Void
    ) -> HACancellable {
        send(request.request) { result in
            completion(result.flatMap { data in
                do {
                    let updated = try T(data: data)
                    return .success(updated)
                } catch {
                    return .failure(.internal(debugDescription: error.localizedDescription))
                }
            })
        }
    }

    // MARK: Subscribing

    private func commonSubscribe(
        to request: HARequest,
        initiated: SubscriptionInitiatedHandler?,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        let sub = HARequestInvocationSubscription(request: request, initiated: initiated, handler: handler)
        requestController.add(sub, completion: {})
        return HACancellableImpl { [requestController] in
            requestController.cancel(sub, completion: {})
        }
    }

    private func commonSubscribe<T>(
        to request: HATypedSubscription<T>,
        initiated: SubscriptionInitiatedHandler?,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        commonSubscribe(to: request.request, initiated: initiated, handler: { token, data in
            do {
                let value = try T(data: data)
                handler(token, value)
            } catch {
                HAGlobal.log("couldn't parse data \(error)")
            }
        })
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
}

// MARK: -

extension HAConnectionImpl {
    func sendRaw(
        identifier: HARequestIdentifier?,
        request: HARequest
    ) {
        var dictionary = request.data
        if let identifier = identifier {
            dictionary["id"] = identifier.rawValue
        }
        dictionary["type"] = request.type.rawValue

        // the only cases where JSONSerialization appears to fail are cases where it throws exceptions too
        // this is bad API from Apple that I don't feel like dealing with :grimace:

        // swiftlint:disable:next force_try
        let data = try! JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
        let string = String(data: data, encoding: .utf8)!

        if request.type == .auth {
            HAGlobal.log("Sending Text: (auth)")
        } else {
            HAGlobal.log("Sending Text: \(string)")
        }

        connection?.write(string: string)
    }
}

extension HAConnectionImpl: HAReconnectManagerDelegate {
    func reconnectManagerWantsReconnection(_ manager: HAReconnectManager) {
        connect(resettingState: false)
    }
}
