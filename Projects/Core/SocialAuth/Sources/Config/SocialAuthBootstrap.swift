import Foundation
import ThirdPartyCore

public enum SocialAuthBootstrap {
    @MainActor
    public static func run(_ socialAuthConfig: SocialAuthConfiguration) {
        KakaoSDK.initSDK(appKey: socialAuthConfig.kakaoAppKey)
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: socialAuthConfig.googleClientID
        )
    }
}
