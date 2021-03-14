import Foundation

/// An entity in Home Assistant
public struct HAEntity: HADataDecodable {
    /// The entity id, e.g. `sun.sun` or `light.office`
    public var entityId: String
    /// The domain of the entity id, e.g. `light` in `light.office`
    public var domain: String
    /// The current state of the entity
    public var state: String
    /// When the entity was last changed
    public var lastChanged: Date
    /// When the entity was last updated
    public var lastUpdated: Date
    /// Attributes of the entity
    public var attributes: HAEntityAttributes
    /// Context of the entity's last update
    public var context: HAResponseEvent.Context

    /// Create an entity from a data response
    /// - Parameter data: The data to create from
    /// - Throws: When the data is missing any required fields
    public init(data: HAData) throws {
        let entityId: String = try data.decode("entity_id")

        try self.init(
            entityId: entityId,
            domain: try {
                guard let dot = entityId.firstIndex(of: ".") else {
                    throw HADataError.couldntTransform(key: "entity_id")
                }

                return String(entityId[..<dot])
            }(),
            state: try data.decode("state"),
            lastChanged: try data.decode("last_changed"),
            lastUpdated: try data.decode("last_updated"),
            attributes: try data.decode("attributes"),
            context: try data.decode("context", transform: HAResponseEvent.Context.init(data:))
        )
    }

    /// Create an entity from individual items
    /// - Parameters:
    ///   - entityId: The entity ID
    ///   - domain: The domain of the entity ID
    ///   - state: The state
    ///   - lastChanged: The date last changed
    ///   - lastUpdated: The date last updated
    ///   - attributes: The attributes of the entity
    ///   - context: The context of the entity
    /// - Throws: When the attributes are missing any required fields
    public init(
        entityId: String,
        domain: String,
        state: String,
        lastChanged: Date,
        lastUpdated: Date,
        attributes: [String: Any],
        context: HAResponseEvent.Context
    ) throws {
        precondition(entityId.starts(with: domain))
        self.entityId = entityId
        self.domain = domain
        self.state = state
        self.lastChanged = lastChanged
        self.lastUpdated = lastUpdated
        self.attributes = try .init(domain: domain, dictionary: attributes)
        self.context = context
    }
}

/// The attributes of the entity's state
public struct HAEntityAttributes {
    /// Convenience access to values inside of the dictionary
    public subscript(key: String) -> Any? { dictionary[key] }
    /// A dictionary representation of the attributes
    /// This contains all keys and values received, including those not parsed or handled otherwise
    public var dictionary: [String: Any]

    /// The display name for the entity, from the `friendly_name` attribute
    public var friendlyName: String? { self["friendly_name"] as? String }
    /// The icon of the entity, from the `icon` attribute
    /// This will be in the format `type:name`, e.g. `mdi:map` or `hass:line`
    public var icon: String? { self["icon"] as? String }

    /// For a zone-type entity, this contains parsed attributes specific to the zone
    public var zone: HAEntityAttributesZone?

    /// Create attributes from individual values
    ///
    /// `domain` is required here as it may inform the per-domain parsing.
    ///
    /// - Parameters:
    ///   - domain: The domain of the entity whose attributes these are for
    ///   - dictionary: The dictionary representation of the
    /// - Throws: When the attributes are missing any required fields, domain-specific
    public init(domain: String, dictionary: [String: Any]) throws {
        self.dictionary = dictionary

        if domain == "zone" {
            self.zone = try .init(data: .dictionary(dictionary))
        } else {
            self.zone = nil
        }
    }
}

/// Entity attributes for Zones
public struct HAEntityAttributesZone: HADataDecodable {
    /// The latitude of the center point of the zone.
    public var latitude: Double
    /// The longitude of the center point of the zone.
    public var longitude: Double
    /// The radius of the zone. The underlying measurement comes from meters.
    public var radius: Measurement<UnitLength>
    /// To only use the zone for automation and hide it from the frontend and not use the zone for device tracker name.
    public var isPassive: Bool

    /// Create attributes from data
    /// - Parameter data: The data to create from
    /// - Throws: When the data is missing any required fields
    public init(data: HAData) throws {
        self.init(
            latitude: try data.decode("latitude"),
            longitude: try data.decode("longitude"),
            radius: try data.decode("radius", transform: { Measurement<UnitLength>(value: $0, unit: .meters) }),
            isPassive: try data.decode("passive")
        )
    }

    /// Create attributes from values
    /// - Parameters:
    ///   - latitude: The center point latitude
    ///   - longitude: The center point longitude
    ///   - radius: The radius of the zone
    ///   - isPassive: Whether the zone is passive
    public init(
        latitude: Double,
        longitude: Double,
        radius: Measurement<UnitLength>,
        isPassive: Bool
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.isPassive = isPassive
    }
}
