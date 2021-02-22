/// Type representing a response type that we do not care about
///
/// Think of this like `Void` -- you don't care about it.
///
/// - TODO: can we somehow get Void to work with the type system? it can't conform to decodable itself :/
public struct HAResponseVoid: HADataDecodable {
    public init(data: HAData) throws {}
}
