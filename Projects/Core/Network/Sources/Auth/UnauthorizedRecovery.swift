/// 401 을 받은 요청을 어떻게 끝낼지.
public enum UnauthorizedRecovery: Equatable, Sendable {
    /// 그때의 토큰으로 다시 보낸다
    case retry
    /// 인증 실패로 끝낸다
    case fail
}
