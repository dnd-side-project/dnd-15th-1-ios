import Domain
import Foundation

enum CoupleDTOMapper {
    /// 연결 코드를 서버 발급 형식(대문자 5자)으로 맞춘다.
    /// 서버도 trim·대문자화를 하지만 클라이언트에서도 같은 정규화를 적용하는 것이 정책이다.
    static func toRequest(inviteCode: String) -> ConnectionCodeRequestDTO {
        ConnectionCodeRequestDTO(
            connectionCode: inviteCode
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
        )
    }

    static func toDomain(_ dto: ConnectionCodeResponseDTO) -> InviteCode {
        InviteCode(
            value: dto.code,
            shareURL: dto.shareUrl.flatMap(URL.init(string:))
        )
    }

    static func toDomain(_ dto: CoupleConnectionStatusResponseDTO) -> Couple? {
        guard dto.connected, let partner = dto.partner else {
            return nil
        }
        // 서버 응답에 커플 식별자 필드가 없어서 connectedAt 을 안정적인 대체 키로 쓴다.
        // 같은 커플이면 항상 같은 값이라 Equatable 비교가 흔들리지 않는다. 진짜 서버 id 는 아니다.
        return Couple(
            id: dto.connectedAt ?? "",
            partnerNickname: partner.nickname,
            partnerIconID: partner.profileIcon
        )
    }
}
