/// Overall error wrapper for the library
public enum HAError: Error, Equatable {
    /// An error occurred in parsing or other internal handling
    case `internal`(debugDescription: String)
    /// An error response from the server indicating a request problem
    case external(ExternalError)

    /// Description of a server-delivered error
    public struct ExternalError: Equatable {
        /// The code provided with the error
        public var code: String
        /// The message provided with the error
        public var message: String

        /// Error produced via a malformed response; rare.
        public static var invalid: ExternalError {
            .init(invalid: ())
        }

        init(_ errorValue: Any?) {
            if let error = errorValue as? [String: String],
               let code = error["code"],
               let message = error["message"] {
                self.init(code: code, message: message)
            } else {
                self.init(invalid: ())
            }
        }

        /// Construct an external error
        ///
        /// Likely just useful for writing unit tests or other constructed situations.
        ///
        /// - Parameters:
        ///   - code: The error code
        ///   - message: The message
        public init(code: String, message: String) {
            self.code = code
            self.message = message
        }

        private init(invalid: ()) {
            self.code = "invalid_error_response"
            self.message = "unable to parse error response"
        }
    }
}
