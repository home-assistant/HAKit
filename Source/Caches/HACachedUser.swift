public extension HACachesContainer {
    /// Cache of the current user.
    var user: HACache<HAResponseCurrentUser> { self[HACacheKeyCurrentUser.self] }
}

/// Key for the cache
private struct HACacheKeyCurrentUser: HACacheKey {
    static func create(connection: HAConnection) -> HACache<HAResponseCurrentUser> {
        .init(
            connection: connection,
            populate: .init(request: .currentUser(), transform: \.incoming),
            subscribe: []
        )
    }
}
