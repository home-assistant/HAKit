public extension HATypedRequest {
    /// Retrieve the current user
    ///
    /// - Returns: A typed request that can be sent via `HAConnectionProtocol`
    static func currentUser() -> HATypedRequest<HAResponseCurrentUser> {
        .init(request: .init(type: .currentUser, data: [:]))
    }
}

/// The current user
public struct HAResponseCurrentUser: HADataDecodable {
    /// The ID of the user; this is a long hex string
    public var id: String
    /// The name of the user, if one is set
    public var name: String?
    /// Whether the user is an owner
    public var isOwner: Bool
    /// Whether the user is an admin
    ///
    /// Admins have access to a different set of commands; you may need to handle failures for commands which
    /// are not allowed to be executed by non-admins.
    public var isAdmin: Bool
    /// Which credentials apply to this user
    public var credentials: [Credential]
    /// Which MFA modules are available, which may include those not enabled
    public var mfaModules: [MFAModule]

    /// A credential authentication provider
    public struct Credential {
        public var type: String
        public var id: String?

        public init(data: HAData) throws {
            self.init(
                type: try data.decode("auth_provider_type"),
                id: data.decode("auth_provider_id", fallback: nil)
            )
        }

        public init(type: String, id: String?) {
            self.type = type
            self.id = id
        }
    }

    /// An MFA module
    public struct MFAModule {
        public var id: String
        public var name: String
        public var isEnabled: Bool

        public init(data: HAData) throws {
            self.init(
                id: try data.decode("id"),
                name: try data.decode("name"),
                isEnabled: try data.decode("enabled")
            )
        }

        public init(id: String, name: String, isEnabled: Bool) {
            self.id = id
            self.name = name
            self.isEnabled = isEnabled
        }
    }

    public init(data: HAData) throws {
        self.init(
            id: try data.decode("id"),
            name: data.decode("name", fallback: nil),
            isOwner: data.decode("is_owner", fallback: false),
            isAdmin: data.decode("is_admin", fallback: false),
            credentials: try data.decode("credentials", fallback: []).compactMap(Credential.init(data:)),
            mfaModules: try data.decode("mfa_modules", fallback: []).compactMap(MFAModule.init(data:))
        )
    }

    public init(
        id: String,
        name: String?,
        isOwner: Bool,
        isAdmin: Bool,
        credentials: [Credential],
        mfaModules: [MFAModule]
    ) {
        self.id = id
        self.name = name
        self.isOwner = isOwner
        self.isAdmin = isAdmin
        self.credentials = credentials
        self.mfaModules = mfaModules
    }
}
