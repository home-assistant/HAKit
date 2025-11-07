import Foundation

internal class HARequestInvocation: Equatable, Hashable {
    private let uniqueID = UUID()
    let request: HARequest
    var identifier: HARequestIdentifier?
    let createdAt: Date

    init(request: HARequest) {
        self.request = request
        self.createdAt = HAGlobal.date()
    }

    static func == (lhs: HARequestInvocation, rhs: HARequestInvocation) -> Bool {
        lhs.uniqueID == rhs.uniqueID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uniqueID)
    }

    var needsAssignment: Bool {
        // for subclasses, too
        identifier == nil
    }

    /// Check if the request's retry duration has expired
    var isRetryTimeoutExpired: Bool {
        guard let duration = request.retryDuration else {
            return false // No duration means never expires
        }
        let elapsed = HAGlobal.date().timeIntervalSince(createdAt)
        let durationInSeconds = duration.converted(to: .seconds).value
        return elapsed > durationInSeconds
    }

    func cancelRequest() -> HATypedRequest<HAResponseVoid>? {
        // most requests do not need another request to be sent to be cancelled
        nil
    }

    func cancel() {
        // for subclasses
    }
}
