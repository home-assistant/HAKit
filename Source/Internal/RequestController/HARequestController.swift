import Foundation

internal protocol HARequestControllerDelegate: AnyObject {
    func requestControllerShouldSendRequests(
        _ requestController: HARequestController
    ) -> Bool
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

    func prepare()
    func resetActive()

    func single(for identifier: HARequestIdentifier) -> HARequestInvocationSingle?
    func subscription(for identifier: HARequestIdentifier) -> HARequestInvocationSubscription?
    func clear(invocation: HARequestInvocationSingle)
}

internal class HARequestControllerImpl: HARequestController {
    private struct State {
        var identifierGenerator = IdentifierGenerator()
        var pending: Set<HARequestInvocation> = Set()
        var active: [HARequestIdentifier: HARequestInvocation] = [:]

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

    private var state = HAProtected<State>(value: .init())

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
                if invocation.request.shouldRetry {
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
            state.active[identifier]
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
            }

            state.pending.remove(invocation)
        }
    }

    func prepare() {
        guard delegate?.requestControllerShouldSendRequests(self) == true else {
            return
        }

        // accumulate delegate callbacks so they are all done _after_ we change state
        var pendingCalls = [(HARequestControllerDelegate, HARequestControllerImpl) -> Void]()

        state.mutate { state in
            for item in state.pending.filter(\.needsAssignment) {
                let identifier = state.identifierGenerator.next()
                state.active[identifier] = item
                item.identifier = identifier

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
