import Foundation

/// 장소 상세 조회 응답. SavedPlace 처럼 Place 를 품고 상세 전용 값을 곁들인다.
/// 별칭은 여기 없다 — 상세 응답이 별칭을 주지 않는다. 저장 수는 place 에 있다.
public struct PlaceDetail: Equatable, Identifiable, Sendable {
    public var id: String { place.id }

    public let place: Place
    /// 내가 저장했는지
    public let isSaved: Bool
    /// 저장 관계. 아무도 저장하지 않았으면 nil
    public let ownership: PlaceOwnership?
    /// 지금 화면이 쓰지 않는다. 장소가 원래 가진 속성이라 담아 둔다
    public let phone: String?
    /// 카카오맵 앱이 없을 때 여는 웹 주소
    public let kakaoPlaceURL: URL?

    public init(
        place: Place,
        isSaved: Bool,
        ownership: PlaceOwnership?,
        phone: String? = nil,
        kakaoPlaceURL: URL? = nil
    ) {
        self.place = place
        self.isSaved = isSaved
        self.ownership = ownership
        self.phone = phone
        self.kakaoPlaceURL = kakaoPlaceURL
    }
}
