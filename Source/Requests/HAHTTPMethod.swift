public struct HAHTTPMethod: RawRepresentable, Hashable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: StringLiteralType) { self.init(rawValue: value) }

    public static var get: Self = "GET"
    public static var post: Self = "POST"
    public static var delete: Self = "DELETE"
    public static var put: Self = "PUT"
    public static var patch: Self = "PATCH"
    public static var head: Self = "HEAD"
    public static var options: Self = "OPTIONS"
}
