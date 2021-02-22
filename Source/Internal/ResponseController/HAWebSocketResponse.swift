internal enum HAWebSocketResponse {
    enum ResponseType: String {
        case result = "result"
        case event = "event"
        case authRequired = "auth_required"
        case authOK = "auth_ok"
        case authInvalid = "auth_invalid"
    }

    enum AuthState {
        case required
        case ok(version: String)
        case invalid
    }

    case result(identifier: HARequestIdentifier, result: Result<HAData, HAError>)
    case event(identifier: HARequestIdentifier, data: HAData)
    case auth(AuthState)

    enum ParseError: Error {
        case unknownType(Any)
        case unknownId(Any)
    }

    enum TempError: Error {
        case parseError(String)
    }

    init(dictionary: [String: Any]) throws {
        guard let type = dictionary["type"] as? String else {
            throw ParseError.unknownType(dictionary["type"] ?? "(unknown)")
        }

        func parseIdentifier() throws -> HARequestIdentifier {
            if let value = (dictionary["id"] as? Int).flatMap(HARequestIdentifier.init(rawValue:)) {
                return value
            } else {
                throw ParseError.unknownId(dictionary["id"] ?? "(unknown)")
            }
        }

        switch ResponseType(rawValue: type) {
        case .result:
            let identifier = try parseIdentifier()

            if dictionary["success"] as? Bool == true {
                self = .result(identifier: identifier, result: .success(.init(value: dictionary["result"])))
            } else {
                self = .result(identifier: identifier, result: .failure(.external(.init(dictionary["error"]))))
            }
        case .event:
            let identifier = try parseIdentifier()
            self = .event(identifier: identifier, data: .init(value: dictionary["event"]))
        case .authRequired:
            self = .auth(.required)
        case .authOK:
            self = .auth(.ok(version: dictionary["ha_version"] as? String ?? "unknown"))
        case .authInvalid:
            self = .auth(.invalid)
        case .none:
            throw TempError.parseError("unknown response type \(type)")
        }
    }
}
