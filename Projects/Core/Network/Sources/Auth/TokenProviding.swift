public protocol TokenProviding: Sendable {
    func accessToken() async throws -> String?
}
