import Foundation

public struct NotificationConfiguration: Sendable {
    public let firebaseOptionsResourceName: String

    public init(firebaseOptionsResourceName: String) {
        self.firebaseOptionsResourceName = firebaseOptionsResourceName
    }
}
