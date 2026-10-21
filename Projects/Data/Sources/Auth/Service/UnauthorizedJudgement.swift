import CoreNetwork

/// 401 판단 결과. 재발급을 기다려야 하면 그 재발급을 함께 들고 온다.
enum UnauthorizedJudgement: Equatable, Sendable {
    case retry
    case fail
    case awaitRefresh(Task<Bool, Never>)

    /// 요청이 받을 답. 재발급을 기다려야 하면 끝날 때까지 기다린다
    func resolve() async -> UnauthorizedRecovery {
        switch self {
        case .retry:
            return .retry
        case .fail:
            return .fail
        case let .awaitRefresh(refresh):
            return await refresh.value ? .retry : .fail
        }
    }
}
