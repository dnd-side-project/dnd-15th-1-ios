import Foundation

public struct AuthBootstrap: Equatable, Sendable {
    public let session: AuthSession
    public let isOnboardingCompleted: Bool
    /// 가입일을 남길지와 첫 로그인 이벤트를 보낼지를 가른다.
    ///
    /// 로그인 응답에서만 참이 될 수 있고 세션 복구에서는 항상 거짓이다
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
