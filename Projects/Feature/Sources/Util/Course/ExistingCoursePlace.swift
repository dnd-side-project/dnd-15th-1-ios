import Domain
import SharedUtils

/// 코스 수정 화면에 이미 담긴 장소. 장소 추가 화면이 지도에 기존 코스를 그릴 때 쓴다.
///
/// 두 화면은 서로의 타입을 모른다. 흐름이 이 값을 그대로 건넨다
public struct ExistingCoursePlace: Equatable, Identifiable, Sendable {
    public let id: String
    public let category: PlaceCategory
    public let coordinate: Coordinate

    public init(id: String, category: PlaceCategory, coordinate: Coordinate) {
        self.id = id
        self.category = category
        self.coordinate = coordinate
    }
}
