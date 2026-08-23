import Foundation

/// 장소 상세 조회 응답. SavedPlace 처럼 Place 를 품고 상세 전용 값을 곁들인다.
/// 별칭은 여기 없다 — 상세 응답이 별칭을 주지 않는다.
public struct PlaceDetail: Equatable, Identifiable, Sendable {
    public var id: String { place.id }

    public let place: Place
    /// 내가 저장했는지. 응답의 savedByMe
    public let savedByMe: Bool
    /// 화면의 「저장한 사람 N」. 응답의 savedMemberCount
    public let savedMemberCount: Int
    /// 저장 관계. 아무도 저장하지 않았으면 nil
    public let ownership: PlaceOwnership?
    /// 지금 화면이 쓰지 않는다. 응답에 있어 담아만 둔다
    public let phone: String?
    /// 지금 화면이 쓰지 않는다. 응답에 있어 담아만 둔다
    public let kakaoPlaceURL: URL?

    public init(
        place: Place,
        savedByMe: Bool,
        savedMemberCount: Int,
        ownership: PlaceOwnership?,
        phone: String? = nil,
        kakaoPlaceURL: URL? = nil
    ) {
        self.place = place
        self.savedByMe = savedByMe
        self.savedMemberCount = savedMemberCount
        self.ownership = ownership
        self.phone = phone
        self.kakaoPlaceURL = kakaoPlaceURL
    }
}
