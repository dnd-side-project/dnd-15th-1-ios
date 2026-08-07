import Foundation
import ThirdPartyCore
import UIKit

public struct GoogleSocialAuthService: SocialAuthService {
    private let clientID: String

    public init(clientID: String) {
        self.clientID = clientID
    }

    public func login() async throws -> String {
        try await loginOnMainActor()
    }

    @MainActor
    private func loginOnMainActor() async throws -> String {
        if GIDSignIn.sharedInstance.configuration == nil {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        guard let presentingViewController = topViewController() else {
            throw SocialAuthError.failed
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingViewController
            )
            guard
                let idToken = result.user.idToken?.tokenString,
                idToken.isEmpty == false
            else {
                throw SocialAuthError.failed
            }
            return idToken
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> SocialAuthError {
        let nsError = error as NSError
        // GIDSignInError.canceled raw value = -5
        if nsError.domain == "com.google.GIDSignIn", nsError.code == -5 {
            return .cancelled
        }
        return .failed
    }

    @MainActor
    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
