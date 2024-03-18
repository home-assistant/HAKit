/// Write audio data to websocket, sttBinaryHandlerId is provided by run-start in Assist pipeline
public struct HASttData: Hashable {
    var sttBinaryHandlerId: UInt8

    public init(sttBinaryHandlerId: UInt8) {
        self.sttBinaryHandlerId = sttBinaryHandlerId
    }
}
