import Foundation

public struct AuthBootstrap: Equatable, Sendable {
    public let session: AuthSession
    public let isOnboardingCompleted: Bool
    public let isNewMember: Bool

    public init(
        session: AuthSession,
        isOnboardingCompleted: Bool,
        isNewMember: Bool
    ) {
        self.session = session
        self.isOnboardingCompleted = isOnboardingCompleted
        self.isNewMember = isNewMember
    }
}
