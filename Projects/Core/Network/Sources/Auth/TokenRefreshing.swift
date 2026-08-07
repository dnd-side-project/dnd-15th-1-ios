public protocol TokenRefreshing: Sendable {
    func refresh() async throws
}
