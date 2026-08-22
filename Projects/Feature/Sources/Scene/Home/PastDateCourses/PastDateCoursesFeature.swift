//
//  PastDateCoursesFeature.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Domain
import ThirdParty

@Reducer
public struct PastDateCoursesFeature {
    /// 한 번에 받아올 코스 수
    static let pageSize = 20

    @ObservableState
    public struct State: Equatable {
        public var courses: [DateSchedule]
        public var totalCount: Int
        public var page: Int
        public var hasNext: Bool
        public var hasLoaded: Bool
        public var isLoadingMore: Bool

        public init(
            courses: [DateSchedule] = [],
            totalCount: Int = 0,
            page: Int = 0,
            hasNext: Bool = true,
            hasLoaded: Bool = false,
            isLoadingMore: Bool = false
        ) {
            self.courses = courses
            self.totalCount = totalCount
            self.page = page
            self.hasNext = hasNext
            self.hasLoaded = hasLoaded
            self.isLoadingMore = isLoadingMore
        }
    }

    public enum Action: Equatable {
        case onAppear
        case coursesLoaded(PastDateCoursePage?)
        case reachedEnd
        case moreCoursesLoaded(PastDateCoursePage?)
        case backButtonTapped
        case createCourseTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case back
            case createCourse
        }
    }

    @Dependency(\.homeClient) var homeClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return loadPage(0, action: Action.coursesLoaded)

            case let .coursesLoaded(page):
                state.hasLoaded = true
                state.courses = page?.courses ?? []
                state.totalCount = page?.totalCount ?? 0
                state.hasNext = page?.hasNext ?? false
                state.page = 1
                return .none

            case .reachedEnd:
                guard state.hasLoaded, state.hasNext, !state.isLoadingMore else { return .none }
                state.isLoadingMore = true
                return loadPage(state.page, action: Action.moreCoursesLoaded)

            case let .moreCoursesLoaded(page):
                state.isLoadingMore = false
                guard let page else { return .none }
                state.courses += page.courses
                state.totalCount = page.totalCount
                state.hasNext = page.hasNext
                state.page += 1
                return .none

            case .backButtonTapped:
                return .send(.delegate(.back))

            case .createCourseTapped:
                return .send(.delegate(.createCourse))

            case .delegate:
                return .none
            }
        }
    }

    // 지정한 페이지를 받아 지정한 액션으로 돌려준다
    private func loadPage(_ page: Int, action: @escaping @Sendable (PastDateCoursePage?) -> Action) -> Effect<Action> {
        .run { [homeClient] send in
            let result = try? await homeClient.pastCourses(page, Self.pageSize)
            await send(action(result))
        }
    }
}
