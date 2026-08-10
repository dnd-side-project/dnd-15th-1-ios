import Domain
import Foundation

struct AuthSessionDTO: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userID: String

    init(_ session: AuthSession) {
        self.accessToken = session.accessToken
        self.refreshToken = session.refreshToken
        self.userID = session.userID
    }

    init(
        accessToken: String,
        refreshToken: String,
        userID: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userID = userID
    }
}
