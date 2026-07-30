import Foundation
import ThirdParty

@Reducer
public struct RootFeature {
    @ObservableState
    public struct State: Equatable {
        public var appCoordinator = AppCoordinatorFeature.State()

        public init(appCoordinator: AppCoordinatorFeature.State = AppCoordinatorFeature.State()) {
            self.appCoordinator = appCoordinator
        }
    }

    public enum Action: Equatable {
        case appCoordinator(AppCoordinatorFeature.Action)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.appCoordinator, action: \.appCoordinator) {
            AppCoordinatorFeature()
        }
    }
}
