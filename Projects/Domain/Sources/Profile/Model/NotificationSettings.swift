import Foundation

/// 마이페이지 알림 설정. 콘텐츠 저장·데이트 일정·마케팅 수신 여부
public struct NotificationSettings: Equatable, Sendable {
    public let contentSavedEnabled: Bool
    public let dateScheduleEnabled: Bool
    public let marketingEnabled: Bool
    /// 사용자가 동의한 마케팅 약관 버전. 아직 동의 안 했으면 nil
    public let marketingConsentVersion: String?
    /// 현재 동의 가능한 마케팅 약관 버전. 마케팅을 처음 켤 때 이 값을 동의 버전으로 보낸다
    public let availableMarketingConsentVersion: String?

    public init(
        contentSavedEnabled: Bool,
        dateScheduleEnabled: Bool,
        marketingEnabled: Bool,
        marketingConsentVersion: String? = nil,
        availableMarketingConsentVersion: String? = nil
    ) {
        self.contentSavedEnabled = contentSavedEnabled
        self.dateScheduleEnabled = dateScheduleEnabled
        self.marketingEnabled = marketingEnabled
        self.marketingConsentVersion = marketingConsentVersion
        self.availableMarketingConsentVersion = availableMarketingConsentVersion
    }
}
