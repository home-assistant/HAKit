import Foundation

internal class HARequestInvocation: Equatable, Hashable {
    private let uniqueID = UUID()
    let request: HARequest
    var identifier: HARequestIdentifier?

    init(request: HARequest) {
        self.request = request
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

    func cancelRequest() -> HATypedRequest<HAResponseVoid>? {
        // most requests do not need another request to be sent to be cancelled
        nil
    }

    func cancel() {
        // for subclasses
    }
}
