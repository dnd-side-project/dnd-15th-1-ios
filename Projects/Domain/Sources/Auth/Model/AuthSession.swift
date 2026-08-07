import Foundation

public struct AuthSession: Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let userID: String

    public init(
        accessToken: String,
        refreshToken: String,
        userID: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userID = userID
    }
}
