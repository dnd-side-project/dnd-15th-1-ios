import Foundation

public struct AuthBootstrap: Equatable, Sendable {
    public let session: AuthSession
    public let isOnboardingCompleted: Bool

    public init(
        session: AuthSession,
        isOnboardingCompleted: Bool
    ) {
        self.session = session
        self.isOnboardingCompleted = isOnboardingCompleted
    }
}
