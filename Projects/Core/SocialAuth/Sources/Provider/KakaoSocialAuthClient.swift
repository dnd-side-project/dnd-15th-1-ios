import Foundation
import ThirdPartyCore

public struct KakaoSocialAuthClient: SocialAuthClient {
    public init() {}

    public func login(nonce: String) async throws -> SocialAuthCredential {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let handler: (OAuthToken?, Error?) -> Void = { token, error in
                    if let error {
                        continuation.resume(throwing: Self.mapError(error))
                        return
                    }

                    guard let idToken = token?.idToken,
                          idToken.isEmpty == false else {
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

                if UserApi.isKakaoTalkLoginAvailable() {
                    UserApi.shared.loginWithKakaoTalk(nonce: nonce, completion: handler)
                } else {
                    UserApi.shared.loginWithKakaoAccount(nonce: nonce, completion: handler)
                }
            }
        }
    }

    private static func mapError(_ error: Error) -> SocialAuthError {
        if let sdkError = error as? SdkError,
           sdkError.isClientFailed,
           sdkError.getClientError().reason == .Cancelled {
            return .cancelled
        }
        return .failed
    }
}
