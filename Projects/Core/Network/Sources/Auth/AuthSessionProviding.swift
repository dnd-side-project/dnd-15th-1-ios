/// 인증 요청이 세션에 묻는 두 가지. 토큰 읽기와 401 뒤의 판단을 한 주인이 맡는다.
public protocol AuthSessionProviding: Sendable {
    /// 요청에 붙일 액세스 토큰. 세션이 없으면 nil 이다
    func accessToken() async throws -> String?
    /// `sentToken` 을 실어 보낸 요청이 401 을 받았다. 다시 보낼지 답한다. 재발급이 필요하면 끝난 뒤에 답한다
    func recover(afterUnauthorized sentToken: String?) async -> UnauthorizedRecovery
}
