import Foundation

/// 클라리티와 믹스패널을 켤 때 넘기는 값 묶음
public struct AnalyticsConfiguration: Sendable {
    /// 클라리티 프로젝트 ID
    public let clarityProjectID: String
    /// 믹스패널 프로젝트 토큰
    public let mixpanelToken: String

    public init(clarityProjectID: String, mixpanelToken: String) {
        self.clarityProjectID = clarityProjectID
        self.mixpanelToken = mixpanelToken
    }
}
