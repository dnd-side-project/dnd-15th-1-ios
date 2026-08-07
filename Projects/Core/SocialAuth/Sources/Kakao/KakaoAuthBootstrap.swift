import Foundation
import SharedLogger
import ThirdPartyCore

public enum KakaoAuthBootstrap {
    @MainActor
    public static func initializeIfNeeded(appKey: String?) {
        guard let appKey, appKey.isEmpty == false else {
            Logger.shared.info(
                "Kakao SDK skipped: app key is empty",
                category: .auth
            )
            return
        }
        KakaoSDK.initSDK(appKey: appKey)
    }
}
