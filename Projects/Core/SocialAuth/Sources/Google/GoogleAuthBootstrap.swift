import Foundation
import SharedLogger
import ThirdPartyCore

public enum GoogleAuthBootstrap {
    @MainActor
    public static func configureIfNeeded(clientID: String?) {
        guard let clientID, clientID.isEmpty == false else {
            Logger.shared.info(
                "Google Sign-In skipped: clientID is empty",
                category: .auth
            )
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }
}
