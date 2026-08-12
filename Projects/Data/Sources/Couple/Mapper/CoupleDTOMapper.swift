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
        // 서버 응답에 커플 식별자 필드가 없다. connectedAt 을 id 처럼 쓰면 진짜 id 로 오인되므로
        // 빈 문자열을 넣어 잘못 쓰였을 때 눈에 보이게 깨지도록 둔다.
        return Couple(
            id: "",
            partnerNickname: partner.nickname,
            partnerIconID: partner.profileIcon
        )
    }
}
