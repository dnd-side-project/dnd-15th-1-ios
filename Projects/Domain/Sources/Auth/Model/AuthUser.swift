import Foundation

public struct AuthUser: Equatable, Identifiable, Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}
