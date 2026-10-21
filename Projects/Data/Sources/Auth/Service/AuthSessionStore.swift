import CoreNetwork
import Foundation
import SharedLogger

/// 세션의 주인. 세션 메모리 사본과 재발급 상태를 한 actor 에 모아, 읽고 판단하고 쓰는 일이 한 차례 안에서 일어나게 한다.
/// 세션을 읽고 쓰는 길은 모두 여기를 지난다.
actor AuthSessionStore: AuthSessionProviding {
    private let authLocal: AuthLocalDataSource
    private let plainRemote: AuthRemoteDataSource

    /// 세션 값의 기준. 키체인은 이 값을 뒤따라 적는다
    private var session: AuthSessionDTO?
    private var isLoaded = false
    private var loading: Task<AuthSessionDTO?, Error>?

    /// 로그인 때만 오른다
    private var sessionNumber = 0
    /// 로그인, 재발급 반영, 세션 삭제 때 오른다. 온보딩 플래그 갱신 때는 오르지 않는다
    private var generation = 0
    /// 액세스 토큰마다 그 토큰을 발급한 세션 번호
    private var tokenSessionNumbers: [String: Int] = [:]
    private var refreshTask: Task<Bool, Never>?
    private var failedAccessToken: String?
    private var isLoggingOut = false
    private var lastWrite: Task<Void, Never>?

    init(authLocal: AuthLocalDataSource, plainRemote: AuthRemoteDataSource) {
        self.authLocal = authLocal
        self.plainRemote = plainRemote
    }

    // MARK: - 인터셉터

    func accessToken() async throws -> String? {
        try await loadIfNeeded()
        return session?.accessToken
    }

    func recover(afterUnauthorized sentToken: String?) async -> UnauthorizedRecovery {
        do {
            try await loadIfNeeded()
        } catch {
            return .fail
        }
        return await judgeUnauthorized(sentToken: sentToken).resolve()
    }

    /// 401 판단. 동기 함수라 판단부터 재발급 시작까지 await 가 끼어들 수 없다
    func judgeUnauthorized(sentToken: String?) -> UnauthorizedJudgement {
        guard let current = session else { return .fail }
        // 다른 세션에서 보낸 요청이다. 토큰 없이 보낸 요청도 여기 든다
        guard let sentToken, tokenSessionNumbers[sentToken] == sessionNumber else { return .fail }
        // 같은 세션의 옛 토큰이다. 재발급 없이 지금 토큰으로 다시 보낸다
        if sentToken != current.accessToken { return .retry }
        if sentToken == failedAccessToken { return .fail }
        // 서버 로그아웃이 보낼 리프레시 토큰이 그사이 바뀌지 않게 한다
        if isLoggingOut { return .fail }
        return .awaitRefresh(joinOrStartRefresh(from: current))
    }

    // MARK: - 세션 읽기·쓰기

    func currentSession() async throws -> AuthSessionDTO? {
        try await loadIfNeeded()
        return session
    }

    /// 키체인 저장이 먼저다. 저장이 끝난 뒤에만 메모리를 바꾸고, 실패하면 메모리는 그대로다
    func login(_ newSession: AuthSessionDTO) async throws {
        try await enqueueWrite { try await self.saveAndAdopt(newSession) }
    }

    /// 플래그만 바꾼다. 토큰과 generation 은 그대로다
    func updateOnboardingCompleted(_ value: Bool) async throws {
        try await loadIfNeeded()
        guard let current = session else { return }
        session = current.with(isOnboardingCompleted: value)
        try await persistMemory()
    }

    // MARK: - 재발급

    private func joinOrStartRefresh(from current: AuthSessionDTO) -> Task<Bool, Never> {
        if let refreshTask {
            return refreshTask
        }
        let startGeneration = generation
        let task = Task { await self.finishRefresh(from: current, startGeneration: startGeneration) }
        refreshTask = task
        return task
    }

    /// 재발급 결과를 한 차례에 반영한다. 시작 뒤 로그인·재발급 반영·세션 삭제가 있었으면 결과를 버린다
    private func finishRefresh(from started: AuthSessionDTO, startGeneration: Int) async -> Bool {
        let result: Result<AuthTokenDTO, Error>
        do {
            result = .success(try await plainRemote.reissue(refreshToken: started.refreshToken))
        } catch {
            result = .failure(error)
        }
        refreshTask = nil
        guard generation == startGeneration else { return false }

        switch result {
        case let .success(token):
            guard let current = session else { return false }
            // 토큰 두 개만 바꾼다. 온보딩 플래그는 지금 메모리 값을 지킨다
            session = AuthDTOMapper.toSessionDTO(token: token, rotating: current)
            generation += 1
            let adopted = generation
            tokenSessionNumbers[token.accessToken] = sessionNumber
            failedAccessToken = nil
            await persistLoggingFailure()
            // 저장을 기다리는 사이 로그인·세션 삭제가 끝났으면, 기다리던 요청이 새 세션의 토큰으로 다시 나가지 않게 한다
            return generation == adopted
        case let .failure(error):
            // 세션 무효로 명세된 재발급 응답은 401 하나다. 그 밖의 실패는 기억하지도 지우지도 않는다
            guard (error as? NetworkError) == .unauthorized else { return false }
            failedAccessToken = started.accessToken
            clearMemory()
            await persistLoggingFailure()
            return false
        }
    }

    // MARK: - 사본 채우기

    /// 처음 불릴 때 한 번 키체인에서 채운다. 동시에 온 호출은 같은 읽기를 기다린다.
    /// 읽기 실패는 기억하지 않는다. 그 호출만 실패하고 다음 호출이 다시 읽는다
    private func loadIfNeeded() async throws {
        if isLoaded {
            return
        }
        let task: Task<AuthSessionDTO?, Error>
        if let loading {
            task = loading
        } else {
            let authLocal = authLocal
            task = Task { try await authLocal.loadSession() }
            loading = task
        }
        do {
            let loaded = try await task.value
            // 기다리는 사이 로그인·로그아웃·탈퇴가 메모리를 정했으면 그 값을 지킨다
            guard !isLoaded else { return }
            session = loaded
            isLoaded = true
            loading = nil
            if let loaded {
                tokenSessionNumbers[loaded.accessToken] = sessionNumber
            }
        } catch {
            if loading == task {
                loading = nil
            }
            throw error
        }
    }

    // MARK: - 메모리·키체인

    private func clearMemory() {
        session = nil
        isLoaded = true
        loading = nil
        generation += 1
    }

    private func saveAndAdopt(_ newSession: AuthSessionDTO) async throws {
        try await authLocal.saveSession(newSession)
        session = newSession
        isLoaded = true
        loading = nil
        sessionNumber += 1
        generation += 1
        failedAccessToken = nil
        // 옛 세션 번호의 토큰은 어차피 맞지 않는다. 쌓이지 않게 비운다
        tokenSessionNumbers = [newSession.accessToken: sessionNumber]
    }

    /// 재발급·만료의 키체인 반영. 메모리가 기준이라 실패해도 로그만 남긴다
    private func persistLoggingFailure() async {
        do {
            try await persistMemory()
        } catch {
            Logger.shared.error("세션 키체인 반영 실패 \(error)", category: .auth)
        }
    }

    /// 쓰는 순간의 메모리 값을 키체인에 적는다. 메모리를 바꾼 직후에 부르므로 키체인의 마지막 값이 메모리의 마지막 값과 같다
    private func persistMemory() async throws {
        try await enqueueWrite { try await self.writeMemoryToKeychain() }
    }

    private func writeMemoryToKeychain() async throws {
        if let session {
            try await authLocal.saveSession(session)
        } else {
            try await authLocal.deleteSession()
        }
    }

    /// 키체인 쓰기는 부른 차례대로 하나씩 한다
    private func enqueueWrite(_ write: @escaping @Sendable () async throws -> Void) async throws {
        let previous = lastWrite
        let current = Task {
            await previous?.value
            try await write()
        }
        lastWrite = Task { _ = await current.result }
        try await current.value
    }
}

// MARK: - 로그아웃·탈퇴

extension AuthSessionStore {
    /// 진행 중인 재발급을 기다린 뒤 서버 로그아웃을 보내고 세션을 지운다.
    /// 메모리를 비우고 generation 을 먼저 올린 뒤 키체인을 지운다. 키체인 삭제 실패는 실패로 알린다
    func logout(sendingLogout send: @Sendable (String) async throws -> Void) async throws {
        try await loadIfNeeded()
        isLoggingOut = true
        if let refreshTask {
            _ = await refreshTask.value
        }
        if let current = session {
            await sendLogout(refreshToken: current.refreshToken, send: send)
        }
        isLoggingOut = false
        clearMemory()
        try await persistMemory()
    }

    /// 로그아웃 요청은 인터셉터가 다시 보내지 않는다(판단이 로그아웃 중이면 실패다). 401 이면 여기서 재발급하고 한 번 더 보낸다
    private func sendLogout(refreshToken: String, send: @Sendable (String) async throws -> Void) async {
        do {
            try await send(refreshToken)
        } catch NetworkError.unauthorized {
            guard let current = session,
                  await joinOrStartRefresh(from: current).value,
                  let rotated = session else {
                return
            }
            try? await send(rotated.refreshToken)
        } catch {
            // 서버 로그아웃 실패는 무시한다. 이 기기의 세션은 지운다
            return
        }
    }
}
