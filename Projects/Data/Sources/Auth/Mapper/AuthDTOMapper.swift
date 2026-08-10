import Domain
import Foundation

enum AuthDTOMapper {
    static func toSessionDTO(_ response: SocialLoginResponseDTO) -> AuthSessionDTO {
        AuthSessionDTO(
            accessToken: response.token.accessToken,
            refreshToken: response.token.refreshToken,
            userID: String(response.memberId)
        )
    }

    static func toSessionDTO(token: AuthTokenDTO, userID: String) -> AuthSessionDTO {
        AuthSessionDTO(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            userID: userID
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
