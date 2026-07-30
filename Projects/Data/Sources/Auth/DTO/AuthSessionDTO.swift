import Domain
import Foundation

struct AuthSessionDTO: Codable, Equatable, Sendable {
    let id: String

    init(_ user: AuthUser) {
        self.id = user.id
    }

    var toDomain: AuthUser {
        AuthUser(id: id)
    }
}
