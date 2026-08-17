import Foundation

/// 커플 상태 조회의 me/partner 공용 프로필.
public struct CoupleMember: Equatable, Sendable {
    public let nickname: String
    public let iconID: Int

    public init(nickname: String, iconID: Int) {
        self.nickname = nickname
        self.iconID = iconID
    }
}
