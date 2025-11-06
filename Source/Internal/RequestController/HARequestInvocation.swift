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
    
    /// Check if the request's retry timeout has expired
    var isRetryTimeoutExpired: Bool {
        guard let timeout = request.retryTimeout else {
            return false // No timeout means never expires
        }
        let elapsed = HAGlobal.date().timeIntervalSince(createdAt)
        return elapsed > timeout
    }

    func cancelRequest() -> HATypedRequest<HAResponseVoid>? {
        // most requests do not need another request to be sent to be cancelled
        nil
    }

    func cancel() {
        // for subclasses
    }
}
