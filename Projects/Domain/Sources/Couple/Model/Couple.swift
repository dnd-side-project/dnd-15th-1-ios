import Foundation

public struct Couple: Equatable, Sendable {
    public let partnerNickname: String
    public let partnerIconID: Int

    public init(
        partnerNickname: String,
        partnerIconID: Int
    ) {
        self.partnerNickname = partnerNickname
        self.partnerIconID = partnerIconID
    }
}
