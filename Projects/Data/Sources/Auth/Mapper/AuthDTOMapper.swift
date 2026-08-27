import Domain
import Foundation

enum AuthDTOMapper {
    static func toSessionDTO(_ response: SocialLoginResponseDTO) -> AuthSessionDTO {
        AuthSessionDTO(
            accessToken: response.token.accessToken,
            refreshToken: response.token.refreshToken,
            userID: String(response.memberId),
            isOnboardingCompleted: response.onboardingCompleted
        )
    }

    /// 토큰 회전 경로. 기존 세션의 온보딩 플래그를 그대로 실어 보내야 다음 복원의 백업 값이 남는다.
    static func toSessionDTO(token: AuthTokenDTO, rotating current: AuthSessionDTO) -> AuthSessionDTO {
        AuthSessionDTO(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            userID: current.userID,
            isOnboardingCompleted: current.isOnboardingCompleted
        )
    }

    static func toDomain(_ dto: AuthSessionDTO) -> AuthSession {
        AuthSession(
            accessToken: dto.accessToken,
            refreshToken: dto.refreshToken,
            userID: dto.userID
        )
    }
}
