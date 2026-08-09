import Foundation
import ThirdPartyCore
import UIKit

public struct GoogleSocialAuthClient: SocialAuthClient {
    public init() {}

    public func login(nonce: String) async throws -> SocialAuthCredential {
        try await loginOnMainActor(nonce: nonce)
    }

    @MainActor
    private func loginOnMainActor(nonce: String) async throws -> SocialAuthCredential {
        guard let presentingViewController = topViewController() else {
            throw SocialAuthError.failed
        }

        do {
            return try await withCheckedThrowingContinuation { continuation in
                GIDSignIn.sharedInstance.signIn(
                    withPresenting: presentingViewController,
                    hint: nil,
                    additionalScopes: nil,
                    nonce: nonce
                ) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard
                        let idToken = result?.user.idToken?.tokenString,
                        idToken.isEmpty == false
                    else {
                        continuation.resume(throwing: SocialAuthError.failed)
                        return
                    }

                    continuation.resume(
                        returning: SocialAuthCredential(
                            idToken: idToken,
                            authorizationCode: nil
                        )
                    )
                }
            }
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
