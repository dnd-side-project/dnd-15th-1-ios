import Foundation
import ThirdPartyCore

public struct KakaoSocialAuthService: SocialAuthService {
    public init() {}

    public func login() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let handler: (OAuthToken?, Error?) -> Void = { token, error in
                    if let error {
                        continuation.resume(throwing: Self.mapError(error))
                        return
                    }

                    guard let accessToken = token?.accessToken,
                          accessToken.isEmpty == false else {
                        continuation.resume(throwing: SocialAuthError.failed)
                        return
                    }

                    continuation.resume(returning: accessToken)
                }

                if UserApi.isKakaoTalkLoginAvailable() {
                    UserApi.shared.loginWithKakaoTalk(completion: handler)
                } else {
                    UserApi.shared.loginWithKakaoAccount(completion: handler)
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
