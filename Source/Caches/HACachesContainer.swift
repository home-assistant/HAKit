/// A cache key for `HACachesContainer`
public protocol HACacheKey {
    /// The value type in the cache, e.g. `T` in `HACache<T>`
    associatedtype Value
    /// Create a cache on a particular connection
    ///
    /// This is called exactly once per connection per cache key.
    ///
    /// - Parameters:
    ///   - connection: The connection to create on
    ///   - data: The data passed to connection request
    /// - Returns: The cache you want to associate with the key
    static func create(
        connection: HAConnection,
        data: [String: Any]
    ) -> HACache<Value>
}

/// Container for caches
///
/// You can create your own cache accessible in this container like so:
///
/// Create a key to represent your cache:
///
/// ```swift
/// struct YourValueTypeKey: HACacheKey {
///     func create(connection: HAConnection) -> HACache<YourValueType> {
///         return HACache(connection: connection, populate: …, subscribe: …)
///     }
/// }
/// ```
///
/// Add a convenience getter to the container itself:
///
/// ```swift
/// extension HACachesContainer {
///     var yourValueType: HACache<YourValueType> { self[YourValueTypeKey.self] }
/// }
/// ```
///
/// Then, access it from a connection like `connection.caches.yourValueType`.
public class HACachesContainer {
    /// Our current initialized caches. We key by the ObjectIdentifier of the meta type, which guarantees a unique
    /// cache entry per key since the identifier is globally unique per type.
    private var values: [ObjectIdentifier: Any] = [:]
    /// The connection we're chained off. This is unowned to avoid a cyclic reference. We expect to crash in this case.
    internal unowned let connection: HAConnection

    /// Create the caches container
    ///
    /// It is not intended that this is accessible outside of the library itself, since we do not make guarantees around
    /// its lifecycle. However, to make it easier to write e.g. a mock connection class, it is made available.
    ///
    /// - Parameter connection: The connection to create using
    public init(connection: HAConnection) {
        self.connection = connection
    }

    /// Get a cache by its key
    ///
    /// - SeeAlso: `HACachesContainer` class description for how to use keys to retrieve caches.
    /// - Subscript: The key to look up
    /// - Returns: Either the existing cache for the key, or a new one created on-the-fly if none was available
    public subscript<KeyType: HACacheKey>(_ key: KeyType.Type, data: [String: Any] = [:]) -> HACache<KeyType.Value> {
        // ObjectIdentifier is globally unique per class _or_ meta type, and we're using meta type here
        let key = ObjectIdentifier(KeyType.self)

        if let value = values[key] as? HACache<KeyType.Value> {
            return value
        }

        let value = KeyType.create(connection: connection, data: data)
        values[key] = value
        return value
    }
}
