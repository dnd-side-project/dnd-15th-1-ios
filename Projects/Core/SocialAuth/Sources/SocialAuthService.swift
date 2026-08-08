import Foundation

public protocol SocialAuthService: Sendable {
    func login() async throws -> String
}
