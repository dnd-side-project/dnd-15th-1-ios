import Foundation

/// 마이페이지 알림 설정. 콘텐츠 저장·데이트 일정·마케팅 수신 여부
public struct NotificationSettings: Equatable, Sendable {
    public let contentSavedEnabled: Bool
    public let dateScheduleEnabled: Bool
    public let marketingEnabled: Bool

    public init(
        contentSavedEnabled: Bool,
        dateScheduleEnabled: Bool,
        marketingEnabled: Bool
    ) {
        self.contentSavedEnabled = contentSavedEnabled
        self.dateScheduleEnabled = dateScheduleEnabled
        self.marketingEnabled = marketingEnabled
    }
}
