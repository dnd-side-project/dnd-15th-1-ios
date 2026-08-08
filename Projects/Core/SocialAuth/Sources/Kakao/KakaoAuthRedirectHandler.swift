import Foundation
import ThirdPartyCore

public enum KakaoAuthRedirectHandler {
    @MainActor
    @discardableResult
    public static func handle(url: URL) -> Bool {
        if AuthApi.isKakaoTalkLoginUrl(url) {
            return AuthController.handleOpenUrl(url: url)
        }
        return false
    }
}
