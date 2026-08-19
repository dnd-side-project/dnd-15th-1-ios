import CoreNetwork
import CoreSocialAuth
import CoreStorage
import Domain
import Foundation

@testable import Data

final class StubNetworkClient: NetworkClient, @unchecked Sendable {
    let name: String
    var responses: [String: Any] = [:]
    var errors: [String: Error] = [:]
    /// 요청이 응답을 돌려주기 직전에 끼어드는 훅. 재발급이 끼어드는 상황을 만든다.
    var onRequest: (@Sendable () async -> Void)?
    private(set) var requestedPaths: [String] = []
    private(set) var requestedKeys: [String] = []
    private(set) var requestedBodies: [String: Data?] = [:]

    init(name: String = "network") {
        self.name = name
    }

    func request<T: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> T {
        record(endpoint)
        await onRequest?()
        if let error = error(for: endpoint) {
            throw error
        }
        guard let value = response(for: endpoint) as? T else {
            throw NetworkError.invalidResponse
        }
        return value
    }

    func request(_ endpoint: some APIEndpoint) async throws {
        record(endpoint)
        await onRequest?()
        if let error = error(for: endpoint) {
            throw error
        }
    }

    private func record(_ endpoint: some APIEndpoint) {
        requestedPaths.append(endpoint.path)
        requestedKeys.append(key(for: endpoint))
        requestedBodies[key(for: endpoint)] = endpoint.body
        requestedBodies[endpoint.path] = endpoint.body
    }

    /// `"POST /path"` 를 먼저 찾고, 없으면 path 로 되돌아간다.
    /// 같은 path 를 메서드로만 구분하는 엔드포인트가 있다.
    private func response(for endpoint: some APIEndpoint) -> Any? {
        responses[key(for: endpoint)] ?? responses[endpoint.path]
    }

    private func error(for endpoint: some APIEndpoint) -> Error? {
        errors[key(for: endpoint)] ?? errors[endpoint.path]
    }

    private func key(for endpoint: some APIEndpoint) -> String {
        "\(endpoint.method.rawValue) \(endpoint.path)"
    }
}

struct StubSocialAuthClient: SocialAuthClient {
    var credential: SocialAuthCredential
    var error: Error?

    func login(nonce: String) async throws -> SocialAuthCredential {
        _ = nonce
        if let error {
            throw error
        }
        return credential
    }
}

final class StubKeychainStorage: KeychainStorage, @unchecked Sendable {
    private var storage: [String: Data] = [:]

    /// 예전 포맷 JSON 을 그대로 심어 하위 호환을 검증한다.
    func seed(rawJSON: String, forKey key: String) {
        storage[key] = Data(rawJSON.utf8)
    }

    func save<T: Codable & Sendable>(_ value: T, forKey key: String) async throws {
        let data = try JSONEncoder().encode(value)
        storage[key] = data
    }

    func get<T: Codable & Sendable>(forKey key: String) async throws -> T? {
        guard let data = storage[key] else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func delete(forKey key: String) async throws {
        storage.removeValue(forKey: key)
    }

    func deleteAll() async throws {
        storage.removeAll()
    }
}

extension SocialAuthCredential {
    static func stub(
        idToken: String = "id-token",
        authorizationCode: String? = nil
    ) -> SocialAuthCredential {
        SocialAuthCredential(idToken: idToken, authorizationCode: authorizationCode)
    }
}

extension SocialAuthCredentialProvider {
    static func stub(
        kakao: StubSocialAuthClient = StubSocialAuthClient(credential: .stub()),
        apple: StubSocialAuthClient = StubSocialAuthClient(credential: .stub()),
        google: StubSocialAuthClient = StubSocialAuthClient(credential: .stub())
    ) -> SocialAuthCredentialProvider {
        SocialAuthCredentialProvider(
            clients: SocialAuthClients(kakao: kakao, apple: apple, google: google)
        )
    }
}

extension AuthRepository {
    /// 프로덕션 조립처럼 profile 호출도 authed client 를 쓴다.
    static func stub(
        plainClient: StubNetworkClient,
        authedClient: StubNetworkClient? = nil,
        authLocal: AuthLocalDataSource,
        socialAuth: SocialAuthCredentialProvider = .stub()
    ) -> AuthRepository {
        let authed = authedClient ?? plainClient
        return AuthRepository(
            authRemote: AuthRemoteDataSource(
                plainClient: plainClient,
                authedClient: authed
            ),
            authLocal: authLocal,
            socialAuth: socialAuth,
            profileRemote: ProfileRemoteDataSource(networkClient: authed)
        )
    }
}

extension AuthLocalDataSource {
    func saveStubSession(
        accessToken: String = "access",
        refreshToken: String = "refresh",
        userID: String = "42",
        isOnboardingCompleted: Bool? = nil
    ) async throws {
        try await saveSession(
            AuthSessionDTO(
                accessToken: accessToken,
                refreshToken: refreshToken,
                userID: userID,
                isOnboardingCompleted: isOnboardingCompleted
            )
        )
    }
}

enum AuthStubFixture {
    static let sessionKey = "auth-session"
    static let noncePath = "/api/v1/auth/nonce"
    static let socialLoginPath = "/api/v1/auth/social-login"
    static let reissuePath = "/api/v1/auth/reissue"
    static let logoutPath = "/api/v1/auth/logout"
    static let memberKey = "GET /api/v1/members/me"

    static let nonce = AuthNonceDTO(nonce: "raw-nonce", expiresAt: "2026-08-09T00:00:00")

    static func socialLogin(
        memberId: Int = 42,
        onboardingCompleted: Bool?
    ) -> SocialLoginResponseDTO {
        SocialLoginResponseDTO(
            memberId: memberId,
            newMember: false,
            onboardingCompleted: onboardingCompleted,
            token: AuthTokenDTO(
                tokenType: "Bearer",
                accessToken: "access",
                refreshToken: "refresh",
                expiresIn: 900
            )
        )
    }

    static func member(onboardingCompleted: Bool) -> MemberResponseDTO {
        MemberResponseDTO(
            memberId: 42,
            onboardingCompleted: onboardingCompleted,
            nickname: nil,
            profileIcon: nil,
            datePreferences: nil
        )
    }
}
