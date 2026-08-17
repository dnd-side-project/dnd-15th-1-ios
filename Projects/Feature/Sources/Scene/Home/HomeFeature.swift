import Domain
import Foundation
import ThirdParty

@Reducer
public struct HomeFeature {
    @ObservableState
    public struct State: Equatable {
        public var nickname: String
        public var partnerName: String?
        public var upcomingSchedule: UpcomingSchedule?
        public var recommendations: [Post]
        public var pastSchedules: [DateSchedule]
        public var savedPlaces: [SavedPlace]

        public var isConnected: Bool {
            partnerName != nil
        }

        public var showsPastSchedules: Bool {
            isConnected && !pastSchedules.isEmpty
        }

        public var visiblePastSchedules: [DateSchedule] {
            Array(pastSchedules.prefix(3))
        }

        public var visibleSavedPlaces: [SavedPlace] {
            Array(savedPlaces.prefix(5))
        }

        public init(
            nickname: String = "듀가나디햄햄",
            partnerName: String? = "만두",
            upcomingSchedule: UpcomingSchedule? = .mock,
            recommendations: [Post] = Post.mocks,
            pastSchedules: [DateSchedule] = DateSchedule.mocks,
            savedPlaces: [SavedPlace] = []
        ) {
            self.nickname = nickname
            self.partnerName = partnerName
            self.upcomingSchedule = upcomingSchedule
            self.recommendations = recommendations
            self.pastSchedules = pastSchedules
            self.savedPlaces = savedPlaces
        }
    }

    public enum Action: Equatable {
        case onAppear
        case savedPlacesLoaded([SavedPlace])
    }

    @Dependency(\.placeClient) var placeClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [placeClient] send in
                    let places = (try? await placeClient.savedPlaces()) ?? []
                    await send(.savedPlacesLoaded(places))
                }

            case let .savedPlacesLoaded(places):
                state.savedPlaces = places
                return .none
            }
        }
    }
}
