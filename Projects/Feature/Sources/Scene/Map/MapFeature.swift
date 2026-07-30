import Foundation
import ThirdParty

@Reducer
public struct MapFeature {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .onAppear:
                return .none
            }
        }
    }
}
