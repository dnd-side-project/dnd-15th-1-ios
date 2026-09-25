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

    /// 연결 요청 응답에서 상대를 꺼낸다. 연결이 안 됐거나 상대가 없으면 불완전한 응답이라 unknown 을 던진다
    static func toPartner(_ dto: CoupleConnectionStatusResponseDTO) throws -> CoupleMember {
        guard dto.connected, let partner = member(dto.partner) else {
            throw CoupleError.unknown
        }
        return partner
    }

    // 연결됐으면 내 정보와 상대가 둘 다 있어야 한다. 하나라도 없으면 sentinel 대신 에러로 올린다.
    // 연결 안 됨은 다른 값을 보지 않는다. 미연결 응답에 내 정보가 빠져도 정상이다
    static func toStatus(_ dto: CoupleConnectionStatusResponseDTO) throws -> CoupleStatus {
        guard dto.connected else {
            return .notConnected
        }
        guard let me = member(dto.me), let partner = member(dto.partner) else {
            throw CoupleError.unknown
        }
        return .connected(me: me, partner: partner, daysTogether: dto.daysTogether)
    }

    private static func member(_ dto: CoupleMemberProfileResponseDTO?) -> CoupleMember? {
        dto.map { CoupleMember(nickname: $0.nickname, iconID: $0.profileIcon) }
    }
}
