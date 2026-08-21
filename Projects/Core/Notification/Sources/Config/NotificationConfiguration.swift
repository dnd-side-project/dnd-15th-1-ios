import Foundation

public struct NotificationConfiguration: Sendable {
    /// 번들에서 찾을 Firebase 설정 plist 이름. 확장자를 뺀 구성별 이름이다 (`GoogleService-Info-Debug`)
    public let firebaseOptionsResourceName: String

    public init(firebaseOptionsResourceName: String) {
        self.firebaseOptionsResourceName = firebaseOptionsResourceName
    }
}
