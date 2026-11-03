import Foundation

/// 장소 검색 한 건. 아무도 저장하지 않은 장소도 담는다.
///
/// 커플 가운데 누가 저장했는지와 별칭을 함께 든다. `SavedPlace` 와 짝을 이루고,
/// 상세·저장 목록·코스가 쓰는 `Place` 에 검색에서만 차는 칸을 만들지 않으려고 따로 둔다
public struct PlaceSearchResult: Equatable, Identifiable, Sendable {
    public var id: String { place.id }
    public let place: Place
    /// 커플 기준 저장 관계. nil 이면 커플 누구도 저장하지 않았다
    public let ownership: PlaceOwnership?
    /// 커플이 붙인 별칭. 지도 검색 응답에는 없어 그쪽 결과는 늘 nil 이다
    public let alias: String?

    public init(place: Place, ownership: PlaceOwnership?, alias: String?) {
        self.place = place
        self.ownership = ownership
        self.alias = alias
    }
}

public extension PlaceSearchResult {
    /// 커플 저장 장소 검색은 저장 목록과 같은 모양으로 온다. 그 한 줄을 검색 결과로 옮긴다
    init(savedPlace: SavedPlace) {
        self.init(place: savedPlace.place, ownership: savedPlace.ownership, alias: savedPlace.alias)
    }

    /// 커플 누군가 저장한 장소면 저장 목록의 한 줄로 되돌린다. 메모·저장 시각은 검색 응답에 없어 비운다
    var savedPlace: SavedPlace? {
        guard let ownership else { return nil }
        return SavedPlace(place: place, ownership: ownership, alias: alias, memo: nil, savedAt: nil)
    }
}
