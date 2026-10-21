import CoreNetwork

/// 인터셉터가 세션에 무엇을 물었는지 기록한다. 401 판단에는 정해 둔 답을 돌려준다.
actor StubSessionProvider: AuthSessionProviding {
    private var token: String?
    private let recovery: UnauthorizedRecovery
    private let tokenAfterRecovery: String?
    private(set) var accessTokenReads = 0
    private(set) var recoveredTokens: [String?] = []

    /// `tokenAfterRecovery` 가 있으면 401 판단 때 토큰을 그 값으로 바꾼다. 재발급을 마친 세션을 흉내 낸다
    init(
        token: String? = "access-token",
        recovery: UnauthorizedRecovery = .fail,
        tokenAfterRecovery: String? = nil
    ) {
        self.token = token
        self.recovery = recovery
        self.tokenAfterRecovery = tokenAfterRecovery
    }

    func accessToken() async throws -> String? {
        accessTokenReads += 1
        return token
    }

    func recover(afterUnauthorized sentToken: String?) async -> UnauthorizedRecovery {
        recoveredTokens.append(sentToken)
        if let tokenAfterRecovery {
            token = tokenAfterRecovery
        }
        return recovery
    }
}
