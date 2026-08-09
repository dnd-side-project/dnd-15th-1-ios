import Foundation

public protocol SocialAuthClient: Sendable {
    func login(nonce: String) async throws -> SocialAuthCredential
}
