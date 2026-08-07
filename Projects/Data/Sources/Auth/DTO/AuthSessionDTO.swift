import Domain
import Foundation

struct AuthSessionDTO: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userId: String

    init(_ session: AuthSession) {
        self.accessToken = session.accessToken
        self.refreshToken = session.refreshToken
        self.userId = session.userId
    }

    init(
        accessToken: String,
        refreshToken: String,
        userId: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
    }

    var toDomain: AuthSession {
        AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: userId
        )
    }
}
