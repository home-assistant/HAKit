import Foundation

internal enum HAWebSocketResponseFixture {
    static func JSONIfy(_ value: String) -> [String: Any] {
        // swiftlint:disable:next force_try force_cast
        try! JSONSerialization.jsonObject(with: value.data(using: .utf8)!, options: []) as! [String: Any]
    }

    static var authRequired = JSONIfy("""
        {"type": "auth_required", "ha_version": "2021.3.0.dev0"}
    """)

    static var authOK = JSONIfy("""
        {"type": "auth_ok", "ha_version": "2021.3.0.dev0"}
    """)

    static var authOKMissingVersion = JSONIfy("""
        {"type": "auth_ok"}
    """)

    static var authInvalid = JSONIfy("""
        {"type": "auth_invalid", "message": "Invalid access token or password"}
    """)

    static var responseEmptyResult = JSONIfy("""
        {"id": 1, "type": "result", "success": true, "result": null}
    """)

    static var responseDictionaryResult = JSONIfy("""
        {"id": 2, "type": "result", "success": true, "result": {"id": "76ce52a813c44fdf80ee36f926d62328"}}
    """)

    static var responseArrayResult = JSONIfy("""
        {"id": 3, "type": "result", "success": true, "result": [{"1": true}, {"2": true}, {"3": true}]}
    """)

    static var responseMissingID = JSONIfy("""
        {"type": "result", "success": "true"}
    """)

    static var responseInvalidID = JSONIfy("""
        {"id": "lol", "type": "result", "success": "true"}
    """)

    static var responseMissingType = JSONIfy("""
        {"id": 9, "success": "true"}
    """)

    static var responseInvalidType = JSONIfy("""
        {"id": 10, "type": "unknown", "success": "true"}
    """)

    static var responseError = JSONIfy("""
        {"id": 4, "type": "result", "success": false, "error": {"code": "unknown_command", "message": "Unknown command."}}
    """)

    static var responseEvent = JSONIfy("""
        {"id": 5, "type": "event", "event": {"result": "ok"}}
    """)
}
