import Foundation

/// 코스에 담을 후보 장소. `GET /api/v1/date-courses/places` 가 준다.
/// 저장 장소 `SavedPlace` 와 응답이 거의 같지만 재사용하지 않는다 —
/// `Place` 에는 이 응답에 없는 `bookmarkCount` · `kakaoPlaceID` 가 있어서 지어내야 한다
public struct CoursePlaceCandidate: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let address: String
    public let category: PlaceCategory
    public let coordinate: Coordinate
    public let ownership: PlaceOwnership
    public let alias: String?
    public let thumbnailURLs: [URL]

    public init(
        id: String,
        name: String,
        address: String,
        category: PlaceCategory,
        coordinate: Coordinate,
        ownership: PlaceOwnership,
        alias: String?,
        thumbnailURLs: [URL]
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.category = category
        self.coordinate = coordinate
        self.ownership = ownership
        self.alias = alias
        self.thumbnailURLs = thumbnailURLs
    }
}
