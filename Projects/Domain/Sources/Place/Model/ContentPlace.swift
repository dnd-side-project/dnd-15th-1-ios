import Foundation

/// 게시글 속 장소와 인스타에서 가져온 장소. 장소에 내가 저장했는지를 곁들인다.
/// 두 응답 모두 저장 수·별칭을 주지 않는다
public struct ContentPlace: Equatable, Identifiable, Sendable {
    public var id: String { place.id }

    public let place: Place
    /// 내가 저장했는지. 화면에 들어올 때의 서버 값이다
    public let isSaved: Bool

    public init(place: Place, isSaved: Bool) {
        self.place = place
        self.isSaved = isSaved
    }
}
