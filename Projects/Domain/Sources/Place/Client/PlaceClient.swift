import Foundation
import ThirdParty

@DependencyClient
public struct PlaceClient: Sendable {
    /// GET /api/v1/places
    public var savedPlaces: @Sendable () async throws -> [SavedPlace]

    /// GET /api/v1/places/search
    public var searchPlaces: @Sendable (_ query: String) async throws -> [Place]

    /// POST /api/v1/places
    public var savePlace: @Sendable (
        _ kakaoPlaceID: String,
        _ query: String,
        _ alias: String?,
        _ memo: String?
    ) async throws -> SavedPlace

    /// DELETE /api/v1/places/{placeId}
    public var removePlace: @Sendable (_ placeID: String) async throws -> Void
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
