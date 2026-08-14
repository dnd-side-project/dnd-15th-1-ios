import Foundation

public enum PlaceError: Error, Equatable, Sendable {
    /// 네트워크 단절/전송 실패
    case network

    /// 세션 만료, 인증 실패(401 계열) 등 인가 불가
    case unauthorized

    /// 대상 장소를 서버가 찾지 못함. `savePlace` 의 `kakaoPlaceID` 가 더 이상 유효하지 않은 경우가 대표적이다
    case notFound

    /// 이미 내 저장 목록에 있는 장소를 다시 저장하려 함
    case alreadySaved

    /// 분류되지 않은 실패
    case unknown
}
