import Foundation
import ThirdParty

@DependencyClient
public struct PlaceClient: Sendable {
    public var savedPlaces: @Sendable () async throws -> [SavedPlace]
    /// 서버가 한 페이지 10건을 고정으로 준다. page 는 0 부터 44 까지다
    public var searchPlaces: @Sendable (_ query: String, _ page: Int) async throws -> PlacePage
    public var savePlace: @Sendable (
        _ kakaoPlaceID: String, _ query: String, _ alias: String?, _ memo: String?
    ) async throws -> SavedPlace
    public var removePlace: @Sendable (_ placeID: String) async throws -> Void
    /// 공용 DB 장소 상세. placeID 는 서버가 숫자로 받는다
    public var placeDetail: @Sendable (_ placeID: Int) async throws -> PlaceDetail
    /// 카카오 장소 상세. query 는 필수다 — 빠지면 서버가 500 을 준다
    public var kakaoPlaceDetail: @Sendable (
        _ kakaoPlaceID: String, _ query: String
    ) async throws -> PlaceDetail
    /// 별칭 수정. alias 가 nil 이거나 공백이면 서버가 별칭을 지운다
    public var updateAlias: @Sendable (_ placeID: Int, _ alias: String?) async throws -> SavedPlace
}

extension PlaceClient: TestDependencyKey {
    public static let testValue = PlaceClient()
    public static let previewValue = PlaceClient.mock
}

public extension DependencyValues {
    var placeClient: PlaceClient {
        get { self[PlaceClient.self] }
        set { self[PlaceClient.self] = newValue }
    }
}
