import Foundation

public struct NotConfiguredSocialAuthService: SocialAuthService {
    private let message: String

    public init(message: String) {
        self.message = message
    }

    public func login() async throws -> String {
        throw SocialAuthError.notConfigured(message: message)
    }
}
