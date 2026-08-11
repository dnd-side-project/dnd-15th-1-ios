import Foundation
import ThirdParty

@Reducer
public struct AppIntroFeature {
    @ObservableState
    public struct State: Equatable {
        public var pageIndex: Int
        public var hasCompleted: Bool

        public init(pageIndex: Int = 0) {
            let lastIndex = max(Self.pageCount - 1, 0)
            self.pageIndex = min(max(pageIndex, 0), lastIndex)
            self.hasCompleted = false
        }

        public var isFirstPage: Bool { pageIndex <= 0 }
        public var isLastPage: Bool { pageIndex >= pageCount - 1 }

        public var pages: [AppIntroPage] { AppIntroStep.pages }

        public var pageCount: Int { Self.pageCount }

        public static var pageCount: Int { AppIntroStep.pages.count }
    }

    public enum Action: Equatable {
        case backButtonTapped
        case nextButtonTapped
        case pageChanged(Int)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case completed
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                guard state.pageIndex > 0 else { return .none }
                state.pageIndex -= 1
                return .none
            case .nextButtonTapped:
                guard !state.hasCompleted else { return .none }
                if state.isLastPage {
                    state.hasCompleted = true
                    return .send(.delegate(.completed))
                }
                state.pageIndex += 1
                return .none
            case let .pageChanged(newIndex):
                let lastIndex = max(State.pageCount - 1, 0)
                let clamped = min(max(newIndex, 0), lastIndex)
                guard state.pageIndex != clamped else { return .none }
                state.pageIndex = clamped
                return .none
            case .delegate:
                return .none
            }
        }
    }
}
