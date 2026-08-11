import Foundation

public struct PartnerPreview: Equatable, Sendable {
    public let nickname: String
    public let iconID: Int

    public init(
        nickname: String,
        iconID: Int
    ) {
        self.nickname = nickname
        self.iconID = iconID
    }
}
