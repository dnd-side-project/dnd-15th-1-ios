import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

@MainActor
public final class AppleSocialAuthClient: NSObject, SocialAuthClient {
    private var continuation: CheckedContinuation<SocialAuthCredential, Error>?
    private var authorizationController: ASAuthorizationController?

    override public init() {
        super.init()
    }

    public nonisolated func login(nonce: String) async throws -> SocialAuthCredential {
        try await loginOnMainActor(nonce: nonce)
    }

    private func loginOnMainActor(nonce: String) async throws -> SocialAuthCredential {
        guard continuation == nil else {
            throw SocialAuthError.cancelled
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            if nonce.isEmpty == false {
                request.nonce = Self.sha256(nonce)
            }

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.authorizationController = controller
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<SocialAuthCredential, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        self.authorizationController = nil

        switch result {
        case let .success(credential):
            continuation.resume(returning: credential)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }

    private static func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func resolvePresentationAnchor() -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        if let firstWindow = scenes.flatMap(\.windows).first {
            return firstWindow
        }
        return ASPresentationAnchor()
    }
}

extension AppleSocialAuthClient: ASAuthorizationControllerDelegate {
    public nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential
            else {
                self.finish(.failure(SocialAuthError.failed))
                return
            }

            guard let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8),
                  identityToken.isEmpty == false else {
                self.finish(.failure(SocialAuthError.failed))
                return
            }

            let authorizationCode = credential.authorizationCode
                .flatMap { String(data: $0, encoding: .utf8) }

            self.finish(
                .success(
                    SocialAuthCredential(
                        idToken: identityToken,
                        authorizationCode: authorizationCode
                    )
                )
            )
        }
    }

    public nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                self.finish(.failure(SocialAuthError.cancelled))
                return
            }
            self.finish(.failure(SocialAuthError.failed))
        }
    }
}

extension AppleSocialAuthClient: ASAuthorizationControllerPresentationContextProviding {
    public nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                AppleSocialAuthClient.resolvePresentationAnchor()
            }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                AppleSocialAuthClient.resolvePresentationAnchor()
            }
        }
    }
}
