import Foundation
import SharedUtils

struct AppConfiguration: Sendable {
    let baseURL: URL
    let bundleID: String
    let kakaoNativeAppKey: String
    let googleClientID: String
    let firebaseOptionsResourceName: String

    static func make() -> AppConfiguration {
        AppConfiguration(
            baseURL: AppInfo.apiBaseURL,
            bundleID: AppInfo.bundleID,
            kakaoNativeAppKey: AppInfo.kakaoNativeAppKey,
            googleClientID: AppInfo.googleClientID,
            firebaseOptionsResourceName: AppInfo.firebaseOptionsResourceName
        )
    }
}
