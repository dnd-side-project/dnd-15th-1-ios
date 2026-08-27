import Foundation

public struct UserProfile: Equatable, Sendable {
    public let nickname: String
    public let iconID: Int
    public let datePreference: DatePreference?

    public init(
        nickname: String,
        iconID: Int,
        datePreference: DatePreference?
    ) {
        self.nickname = nickname
        self.iconID = iconID
        self.datePreference = datePreference
    }
}
