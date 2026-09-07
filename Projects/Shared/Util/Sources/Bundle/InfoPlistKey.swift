import Foundation

public enum InfoPlistKey: String, Sendable {
    case apiBaseURL = "API_BASE_URL"
    case kakaoNativeAppKey = "KAKAO_NATIVE_APP_KEY"
    case googleClientID = "GOOGLE_CLIENT_ID"
    case googleReversedClientID = "GOOGLE_REVERSED_CLIENT_ID"
    case firebaseOptionsResource = "FIREBASE_OPTIONS_RESOURCE"
    case clarityProjectID = "CLARITY_PROJECT_ID"
    /// 믹스패널 프로젝트 토큰
    case mixpanelProjectToken = "MIXPANEL_PROJECT_TOKEN"
}
