import Foundation

public struct InviteCode: Equatable, Sendable {
    public let value: String
    public let shareURL: URL?

    public init(
        value: String,
        shareURL: URL?
    ) {
        self.value = value
        self.shareURL = shareURL
    }
}
