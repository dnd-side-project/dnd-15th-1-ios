import Domain
import Foundation
import ThirdParty

@Reducer
public struct MapFeature {
    @ObservableState
    public struct State: Equatable {
        public var camera: MapCamera = .ansan
        public var places: [SavedPlace] = []

        public var markers: [MapMarker] {
            places.map { saved in
                MapMarker(
                    id: saved.id,
                    coordinate: saved.place.coordinate,
                    kind: .place
                )
            }
        }

        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
        case savedPlacesResponse([SavedPlace])
        case cameraChanged(MapCamera)
        case markerTapped(String)
    }

    private enum CancelID {
        case load
    }

    @Dependency(\.placeClient) var placeClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [placeClient] send in
                    // 로딩·에러 화면은 Cycle 1. 실패하면 빈 배열이다
                    let places = (try? await placeClient.savedPlaces()) ?? []
                    await send(.savedPlacesResponse(places))
                }
                // 탭을 오가며 여러 번 들어오면 늦게 온 옛 응답이 새 응답을 덮는다
                .cancellable(id: CancelID.load, cancelInFlight: true)

            case let .savedPlacesResponse(places):
                state.places = places
                return .none

            case let .cameraChanged(camera):
                state.camera = camera
                return .none

            case .markerTapped:
                // 상세 진입은 Cycle 2
                return .none
            }
        }
    }
}
