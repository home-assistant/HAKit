/// Write audio data to websocket, sttBinaryHandlerId is provided by run-start in Assist pipeline
public struct HASttHandlerId: Hashable {
    var rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

public extension HATypedRequest {
    /// Send binary stream STT data
    /// - Parameters:
    ///   - sttHandlerId: Handler Id provided by run-start event from Assist pipeline
    ///   - audioDataBase64Encoded: Audio data base 64 encoded
    /// - Returns: A typed request that can be sent via `HAConnection`
    static func sendSttData(sttHandlerId: UInt8, audioDataBase64Encoded: String) -> HATypedRequest<HAResponseVoid> {
        .init(request: .init(type: .sttData(.init(rawValue: sttHandlerId)), data: [
            "audioData": audioDataBase64Encoded,
        ]))
    }
}
