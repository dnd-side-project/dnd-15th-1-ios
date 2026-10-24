import CoreNetwork
import Foundation

@testable import Data

/// 세션 주인 테스트가 함께 쓰는 값과 조립.
enum AuthSessionStoreFixture {
    /// 신호가 오지 않을 때만 걸리는 제한 시간. 통과하는 실행에서는 기다리지 않는다
    static let signalTimeout: TimeInterval = 3

    static func session(
        access: String = "A1",
        refresh: String = "R1",
        userID: String = "1",
        isOnboardingCompleted: Bool? = true
    ) -> AuthSessionDTO {
        AuthSessionDTO(
            accessToken: access,
            refreshToken: refresh,
            userID: userID,
            isOnboardingCompleted: isOnboardingCompleted
        )
    }

    static func reissueReply(access: String, refresh: String) -> ScriptedNetworkClient.Reply {
        .value(
            AuthTokenDTO(
                tokenType: "Bearer",
                accessToken: access,
                refreshToken: refresh,
                expiresIn: 900
            )
        )
    }

    /// 키체인에 `seed` 를 심고 그 키체인을 읽는 세션 주인을 만든다. 재발급은 `server` 로 간다
    static func makeStore(
        seed: AuthSessionDTO?,
        keychain: SerialKeychainStorage = SerialKeychainStorage(),
        server: ScriptedNetworkClient
    ) async throws -> AuthSessionStore {
        let local = AuthLocalDataSource(storage: keychain)
        if let seed {
            try await local.saveSession(seed)
        }
        return AuthSessionStore(
            authLocal: local,
            plainRemote: AuthRemoteDataSource(plainClient: server, authedClient: server)
        )
    }

    /// 키체인에 지금 남은 세션. 키체인 읽기 횟수를 하나 늘린다
    static func storedSession(in keychain: SerialKeychainStorage) async throws -> AuthSessionDTO? {
        try await AuthLocalDataSource(storage: keychain).loadSession()
    }

    /// 요청 본문에 실린 리프레시 토큰들. 본문이 없거나 읽을 수 없으면 nil 이다
    static func refreshTokens(in bodies: [Data?]) -> [String?] {
        bodies.map { body in
            body.flatMap { try? JSONDecoder().decode(RefreshTokenBody.self, from: $0).refreshToken }
        }
    }

    private struct RefreshTokenBody: Decodable {
        let refreshToken: String
    }
}

/// 여러 작업에서 들어온 값을 들어온 차례대로 모은다.
actor Recorder<Value: Sendable> {
    private(set) var values: [Value] = []

    func append(_ value: Value) {
        values.append(value)
    }
}

extension AuthSessionStore {
    /// 401 판단 `count` 개를 이 actor 의 한 차례 안에서 모두 끝낸다. 그사이 재발급이 돌거나 반영될 틈이 없다
    func judgeTogether(_ count: Int, sentToken: String?) -> [UnauthorizedJudgement] {
        (0..<count).map { _ in judgeUnauthorized(sentToken: sentToken) }
    }
}

/// 로그아웃이 시작될 때까지 양보하며 기다린다. 재발급이 진행 중일 때만 쓴다.
/// 로그아웃 중에는 지금 토큰의 401 판단도 실패가 된다. 그 전의 판단은 진행 중인 재발급에 합류할 뿐 새로 시작하지 않는다.
func waitUntilLoggingOut(_ store: AuthSessionStore, currentToken: String) async -> Bool {
    for _ in 0..<100_000 {
        if await store.judgeUnauthorized(sentToken: currentToken) == .fail {
            return true
        }
        await Task.yield()
    }
    return false
}

/// 세션 주인의 메모리 액세스 토큰이 `token` 이 될 때까지 양보하며 기다린다.
func waitUntilAccessToken(_ store: AuthSessionStore, is token: String) async -> Bool {
    for _ in 0..<100_000 {
        if (try? await store.currentSession())?.accessToken == token {
            return true
        }
        await Task.yield()
    }
    return false
}
