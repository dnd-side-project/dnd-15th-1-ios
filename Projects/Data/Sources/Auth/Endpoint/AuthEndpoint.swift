import CoreNetwork
import Domain
import Foundation

enum AuthEndpoint: APIEndpoint {
    case issueNonce(provider: AuthProvider)
    case socialLogin(
        provider: AuthProvider,
        idToken: String,
        authorizationCode: String?,
        nonce: String
    )
    case reissue(refreshToken: String)
    case logout(refreshToken: String)

    var path: String {
        switch self {
        case .issueNonce:
            return "/api/v1/auth/nonce"
        case .socialLogin:
            return "/api/v1/auth/social-login"
        case .reissue:
            return "/api/v1/auth/reissue"
        case .logout:
            return "/api/v1/auth/logout"
        }
    }

    var method: HTTPMethod {
        .post
    }

    var headers: [String: String] {
        [:]
    }

    var body: Data? {
        let encoder = NetworkJSONCoding.makeEncoder()
        switch self {
        case let .issueNonce(provider):
            return try? encoder.encode(["provider": AuthProviderAPI(provider).rawValue])
        case let .socialLogin(provider, idToken, authorizationCode, nonce):
            struct Body: Encodable {
                let provider: String
                let idToken: String
                let authorizationCode: String?
                let nonce: String
            }
            return try? encoder.encode(
                Body(
                    provider: AuthProviderAPI(provider).rawValue,
                    idToken: idToken,
                    authorizationCode: authorizationCode,
                    nonce: nonce
                )
            )
        case let .reissue(refreshToken):
            return try? encoder.encode(AuthReissueRequestDTO(refreshToken: refreshToken))
        case let .logout(refreshToken):
            return try? encoder.encode(AuthLogoutRequestDTO(refreshToken: refreshToken))
        }
    }
}

private enum AuthProviderAPI: String, Encodable, Sendable {
    case kakao = "KAKAO"
    case google = "GOOGLE"
    case apple = "APPLE"

    init(_ provider: AuthProvider) {
        switch provider {
        case .kakao:
            self = .kakao
        case .google:
            self = .google
        case .apple:
            self = .apple
        }
    }
}
