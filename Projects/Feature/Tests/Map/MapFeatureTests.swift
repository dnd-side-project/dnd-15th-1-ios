import Domain
import Feature
import ThirdParty
import XCTest

@MainActor
final class MapFeatureTests: XCTestCase {
    private let savedPlaces: [SavedPlace] = [
        .fixture(id: "1", latitude: 37.3128, longitude: 126.9040),
        .fixture(id: "2", latitude: 37.3141, longitude: 126.9068),
    ]

    func test_onAppear_저장장소_상태반영() async {
        let places = savedPlaces
        let callCount = LockIsolated(0)
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.savedPlaces = {
                callCount.withValue { $0 += 1 }
                return places
            }
        }

        await store.send(.onAppear)
        await store.receive(\.savedPlacesResponse) {
            $0.places = places
        }
        XCTAssertEqual(callCount.value, 1)
    }

    func test_onAppear_실패해도_빈배열로_유지() async {
        var initialState = MapFeature.State()
        initialState.places = savedPlaces

        let store = TestStore(initialState: initialState) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.savedPlaces = { throw PlaceError.network }
        }

        await store.send(.onAppear)
        await store.receive(\.savedPlacesResponse) {
            $0.places = []
        }
    }

    func test_markers_장소에서_파생() async {
        let places = savedPlaces
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        }

        // `markers` 는 계산 프로퍼티라 TestStore 상태 비교에 안 걸린다. 따로 단언한다
        await store.send(.savedPlacesResponse(places)) {
            $0.places = places
        }

        XCTAssertEqual(
            store.state.markers,
            [
                MapMarker(
                    id: "1",
                    coordinate: Coordinate(latitude: 37.3128, longitude: 126.9040),
                    kind: .place
                ),
                MapMarker(
                    id: "2",
                    coordinate: Coordinate(latitude: 37.3141, longitude: 126.9068),
                    kind: .place
                ),
            ]
        )
    }

    func test_cameraChanged_카메라갱신() async {
        let moved = MapCamera(
            center: Coordinate(latitude: 37.5006, longitude: 127.0366),
            zoomLevel: 16
        )
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        }

        await store.send(.cameraChanged(moved)) {
            $0.camera = moved
        }
    }
}

private extension SavedPlace {
    static func fixture(id: String, latitude: Double, longitude: Double) -> SavedPlace {
        SavedPlace(
            place: Place(
                id: id,
                kakaoPlaceID: "kakao-\(id)",
                name: "장소 \(id)",
                category: .cafe,
                address: "경기도 안산시 상록구 건건동 \(id)",
                roadAddress: "경기도 안산시 상록구 건건로 \(id)",
                coordinate: Coordinate(latitude: latitude, longitude: longitude),
                bookmarkCount: 0,
                thumbnailURLs: []
            ),
            ownership: .mine,
            alias: nil,
            memo: nil,
            savedAt: Date(timeIntervalSince1970: 1_786_000_000)
        )
    }
}
