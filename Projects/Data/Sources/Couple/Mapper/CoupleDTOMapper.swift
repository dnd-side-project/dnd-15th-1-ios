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
        return Couple(
            partnerNickname: partner.nickname,
            partnerIconID: partner.profileIcon
        )
    }

    static func toStatus(_ dto: CoupleConnectionStatusResponseDTO) -> CoupleStatus {
        CoupleStatus(
            connected: dto.connected,
            me: member(dto.me) ?? CoupleMember(nickname: "", iconID: 0),
            partner: dto.connected ? member(dto.partner) : nil,
            daysTogether: dto.daysTogether
        )
    }

    private static func member(_ dto: CoupleMemberProfileResponseDTO?) -> CoupleMember? {
        dto.map { CoupleMember(nickname: $0.nickname, iconID: $0.profileIcon) }
    }
}
