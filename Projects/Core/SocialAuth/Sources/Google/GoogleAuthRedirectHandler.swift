import Foundation
import ThirdPartyCore

public enum GoogleAuthRedirectHandler {
    @MainActor
    @discardableResult
    public static func handle(url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}
