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

    /// 토큰 회전 경로. 토큰 두 개만 바꾸고 회원 식별자와 온보딩 플래그는 `current`(세션 주인의 지금 메모리 값)를 지킨다.
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
