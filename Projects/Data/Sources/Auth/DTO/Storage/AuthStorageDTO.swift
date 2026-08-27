import Domain
import Foundation

struct AuthSessionDTO: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userID: String
    /// 키에 값이 없던 기존 저장 JSON 도 디코딩되어야 하므로 optional 이다.
    let isOnboardingCompleted: Bool?

    init(
        _ session: AuthSession,
        isOnboardingCompleted: Bool? = nil
    ) {
        self.accessToken = session.accessToken
        self.refreshToken = session.refreshToken
        self.userID = session.userID
        self.isOnboardingCompleted = isOnboardingCompleted
    }

    init(
        accessToken: String,
        refreshToken: String,
        userID: String,
        isOnboardingCompleted: Bool? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userID = userID
        self.isOnboardingCompleted = isOnboardingCompleted
    }

    func with(isOnboardingCompleted: Bool) -> AuthSessionDTO {
        AuthSessionDTO(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userID: userID,
            isOnboardingCompleted: isOnboardingCompleted
        )
    }
}
