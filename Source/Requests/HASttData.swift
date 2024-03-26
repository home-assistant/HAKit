/// Write audio data to websocket, sttBinaryHandlerId is provided by run-start in Assist pipeline
public struct HASttHandlerId: Hashable {
    var rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

public extension HATypedRequest {
    /// Send binary stream STT data
    /// - Returns: A typed request that can be sent via `HAConnection`
    static func sendSttData(sttHandlerId: UInt8, audioDataBase64Encoded: String) -> HATypedRequest<HAResponseVoid> {
        .init(request: .init(type: .sttData(.init(rawValue: sttHandlerId)), data: [
            "audioData": audioDataBase64Encoded
        ]))
    }
}
