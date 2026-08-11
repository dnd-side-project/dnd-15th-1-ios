import Foundation

public struct Couple: Equatable, Sendable {
    public let id: String
    public let partnerNickname: String
    public let partnerIconID: Int

    public init(
        id: String,
        partnerNickname: String,
        partnerIconID: Int
    ) {
        self.id = id
        self.partnerNickname = partnerNickname
        self.partnerIconID = partnerIconID
    }
}
