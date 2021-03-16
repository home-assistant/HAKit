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

    func add(_ invocation: HARequestInvocation, completion: @escaping () -> Void)
    func cancel(_ request: HARequestInvocation, completion: @escaping () -> Void)

    func prepare(completion handler: @escaping () -> Void)
    func resetActive(completion: @escaping () -> Void)

    func single(for identifier: HARequestIdentifier) -> HARequestInvocationSingle?
    func subscription(for identifier: HARequestIdentifier) -> HARequestInvocationSubscription?
    func clear(invocation: HARequestInvocationSingle, completion: @escaping () -> Void)
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

    private var state = HAProtected<State>(value: .init())

    func add(_ invocation: HARequestInvocation, completion: @escaping () -> Void) {
        state.mutate(using: { state in
            state.pending.insert(invocation)
        }, then: { [self] in
            prepare(completion: completion)
        })
    }

    func cancel(_ request: HARequestInvocation, completion: @escaping () -> Void) {
        // intentionally grabbed before entering the mutex
        let identifier = request.identifier
        let cancelRequest = request.cancelRequest()
        request.cancel()

        state.mutate(using: { state in
            state.pending.remove(request)

            if let identifier = identifier {
                state.active[identifier] = nil
            }

            if let cancelRequest = cancelRequest {
                state.pending.insert(HARequestInvocationSingle(
                    request: cancelRequest.request,
                    completion: { _ in }
                ))
            }
        }, then: { [self] in
            prepare(completion: completion)
        })
    }

    func resetActive(completion: @escaping () -> Void) {
        state.mutate(using: { state in
            for invocation in state.pending {
                if invocation.request.shouldRetry {
                    invocation.identifier = nil
                } else {
                    state.pending.remove(invocation)
                }
            }

            state.active.removeAll()
            state.identifierGenerator.reset()
        }, then: completion)
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
    func clear(invocation: HARequestInvocationSingle, completion: @escaping () -> Void) {
        state.mutate(using: { state in
            if let identifier = invocation.identifier {
                state.active[identifier] = nil
            }

            state.pending.remove(invocation)
        }, then: completion)
    }

    func prepare(completion handler: @escaping () -> Void) {
        guard delegate?.requestControllerShouldSendRequests(self) == true else {
            handler()
            return
        }

        let queue = DispatchQueue(label: "request-controller-callback", target: .main)
        queue.suspend()

        state.mutate(using: { state in
            for item in state.pending.filter(\.needsAssignment) {
                let identifier = state.identifierGenerator.next()
                state.active[identifier] = item
                item.identifier = identifier

                queue.async { [self] in
                    delegate?.requestController(self, didPrepareRequest: item.request, with: identifier)
                }
            }
        }, then: {
            queue.resume()
            queue.async(flags: .barrier, execute: handler)
        })
    }
}
