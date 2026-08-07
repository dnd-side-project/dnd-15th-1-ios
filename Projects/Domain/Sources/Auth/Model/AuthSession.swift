import Foundation

public struct AuthSession: Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let userId: String

    public init(
        accessToken: String,
        refreshToken: String,
        userId: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
    }
}
