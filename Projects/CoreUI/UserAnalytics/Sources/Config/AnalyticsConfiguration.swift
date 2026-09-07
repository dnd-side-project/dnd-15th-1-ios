import Foundation

public struct AnalyticsConfiguration: Sendable {
    public let clarityProjectID: String
    public let mixpanelToken: String

    public init(clarityProjectID: String, mixpanelToken: String) {
        self.clarityProjectID = clarityProjectID
        self.mixpanelToken = mixpanelToken
    }
}
