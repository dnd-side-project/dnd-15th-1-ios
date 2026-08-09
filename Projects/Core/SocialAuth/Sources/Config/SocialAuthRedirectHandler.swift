import Foundation
import ThirdPartyCore

public enum SocialAuthRedirectHandler {
    @MainActor
    @discardableResult
    public static func handle(url: URL) -> Bool {
        if handleKakao(url: url) {
            return true
        }
        if handleGoogle(url: url) {
            return true
        }
        return false
    }

    @MainActor
    private static func handleKakao(url: URL) -> Bool {
        if AuthApi.isKakaoTalkLoginUrl(url) {
            return AuthController.handleOpenUrl(url: url)
        }
        return false
    }

    @MainActor
    private static func handleGoogle(url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}
