import Foundation

internal struct HARequestControllerAllowedSendKind: OptionSet {
    var rawValue: Int

    static let webSocket: Self = .init(rawValue: 0b1)
    static let rest: Self = .init(rawValue: 0b10)
    static let sttData: Self = .init(rawValue: 0b11)
    static let all: Self = [.webSocket, .rest, .sttData]

    func allows(requestType: HARequestType) -> Bool {
        switch requestType {
        case .webSocket:
            return contains(.webSocket)
        case .rest:
            return contains(.rest)
        case .sttData:
            return contains(.sttData)
        }
    }
}

internal protocol HARequestControllerDelegate: AnyObject {
    func requestControllerAllowedSendKinds(
        _ requestController: HARequestController
    ) -> HARequestControllerAllowedSendKind
    func requestController(
        _ requestController: HARequestController,
        didPrepareRequest request: HARequest,
        with identifier: HARequestIdentifier
    )
}

internal protocol HARequestController: AnyObject {
    var delegate: HARequestControllerDelegate? { get set }
    var workQueue: DispatchQueue { get set }

    func add(_ invocation: HARequestInvocation)
    func cancel(_ request: HARequestInvocation)

    var retrySubscriptionsEvents: [HAEventType] { get }
    func retrySubscriptions()

    func prepare()
    func resetActive()

    func single(for identifier: HARequestIdentifier) -> HARequestInvocationSingle?
    func subscription(for identifier: HARequestIdentifier) -> HARequestInvocationSubscription?
    func clear(invocation: HARequestInvocationSingle)
}

internal class HARequestControllerImpl: HARequestController {
    private struct State {
        @HASchedulingTimer var retrySubscriptionsTimer: Timer?
        var identifierGenerator = IdentifierGenerator()
        var pending: Set<HARequestInvocation> = Set()
        var active: [HARequestIdentifier: HARequestInvocation] = [:]
        var perpetual: [HARequestIdentifier: HARequestInvocation] = [:]

        struct IdentifierGenerator {
            private var lastIdentifierInteger = 0

            mutating func next() -> HARequestIdentifier {
                lastIdentifierInteger += 1
                return .init(rawValue: lastIdentifierInteger)
            }

            mutating func reset() {
                // we don't actually change the identifier
                // by not reusing ids -- even across connections -- we can reduce bugs
            }
        }
    }

    weak var delegate: HARequestControllerDelegate?
    var workQueue: DispatchQueue = .global()

    private let state = HAProtected<State>(value: .init())
    internal var retrySubscriptionsTimer: Timer? {
        // this method exists exclusively for tests so we don't need to expose state
        state.read(\.retrySubscriptionsTimer)
    }

    func add(_ invocation: HARequestInvocation) {
        state.mutate { state in
            state.pending.insert(invocation)
        }

        prepare()
    }

    func cancel(_ request: HARequestInvocation) {
        // intentionally grabbed before entering the mutex
        let identifier = request.identifier
        let cancelRequest = request.cancelRequest()
        request.cancel()

        state.mutate { state in
            let removed = state.pending.remove(request)

            guard removed != nil else {
                // Extraneous cancel, either after already cancelling or after finished, which is fine but we also noop
                return
            }

            if let identifier = identifier {
                state.active[identifier] = nil
            }

            if let cancelRequest = cancelRequest {
                state.pending.insert(HARequestInvocationSingle(
                    request: cancelRequest.request,
                    completion: { _ in }
                ))
            }
        }

        prepare()
    }

    func resetActive() {
        state.mutate { state in
            for invocation in state.pending {
                if invocation.request.shouldRetry, !invocation.isRetryTimeoutExpired {
                    invocation.identifier = nil
                } else {
                    state.pending.remove(invocation)
                }
            }

            state.active.removeAll()
            state.identifierGenerator.reset()
        }
    }

    private func invocation(for identifier: HARequestIdentifier) -> HARequestInvocation? {
        state.read { state in
            state.active[identifier] ?? state.perpetual[identifier]
        }
    }

    func single(for identifier: HARequestIdentifier) -> HARequestInvocationSingle? {
        invocation(for: identifier) as? HARequestInvocationSingle
    }

    func subscription(for identifier: HARequestIdentifier) -> HARequestInvocationSubscription? {
        invocation(for: identifier) as? HARequestInvocationSubscription
    }

    // only single invocations can be cleared, as subscriptions need to be cancelled
    func clear(invocation: HARequestInvocationSingle) {
        state.mutate { state in
            if let identifier = invocation.identifier {
                state.active[identifier] = nil
                state.perpetual[identifier] = nil
            }

            state.pending.remove(invocation)
        }
    }

    var retrySubscriptionsEvents: [HAEventType] { [
        .coreConfigUpdated,
        .componentLoaded,
    ] }

    func retrySubscriptions() {
        state.mutate { state in
            let fireDate = HAGlobal.date().addingTimeInterval(5.0)

            if let timer = state.retrySubscriptionsTimer, timer.isValid {
                timer.fireDate = fireDate
            } else {
                let timer = Timer(fire: fireDate, interval: 0, repeats: false, block: { [weak self] _ in
                    self?.delayedRetrySubscriptions()
                })
                timer.tolerance = 5.0
                state.retrySubscriptionsTimer = timer
            }
        }
    }

    private func delayedRetrySubscriptions() {
        state.mutate { state in
            state.retrySubscriptionsTimer = nil
            state.pending
                .compactMap { $0 as? HARequestInvocationSubscription }
                .filter { $0.needsRetry && $0.request.shouldRetry }
                .forEach { $0.identifier = nil }
        }

        prepare()
    }

    func prepare() {
        guard let allowed = delegate?.requestControllerAllowedSendKinds(self), !allowed.isEmpty else {
            return
        }

        // accumulate delegate callbacks so they are all done _after_ we change state
        var pendingCalls = [(HARequestControllerDelegate, HARequestControllerImpl) -> Void]()

        state.mutate { state in
            let items = state.pending
                .filter { $0.needsAssignment && allowed.allows(requestType: $0.request.type) }

            for item in items {
                let identifier = state.identifierGenerator.next()
                item.identifier = identifier

                if item.request.type.isPerpetual {
                    state.perpetual[identifier] = item
                    state.pending.remove(item)
                } else {
                    state.active[identifier] = item
                }

                pendingCalls.append { delegate, controller in
                    delegate.requestController(controller, didPrepareRequest: item.request, with: identifier)
                }
            }
        }

        if let delegate = delegate {
            pendingCalls.forEach { $0(delegate, self) }
        }
    }
}
