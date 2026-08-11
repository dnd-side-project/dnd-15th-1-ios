import Foundation

public enum ProfileError: Error, Equatable, Sendable {
    /// 닉네임 형식/정책 위반
    case invalidNickname

    /// 네트워크 단절/전송 실패
    case network

    /// 세션 만료, 인증 실패(401 계열) 등 인가 불가
    case unauthorized

    /// 분류되지 않은 실패
    case unknown
}
