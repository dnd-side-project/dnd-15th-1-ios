import Foundation

public struct SocialAuthCredential: Sendable, Equatable {
    public let idToken: String
    public let authorizationCode: String?

    public init(idToken: String, authorizationCode: String? = nil) {
        self.idToken = idToken
        self.authorizationCode = authorizationCode
    }
}
