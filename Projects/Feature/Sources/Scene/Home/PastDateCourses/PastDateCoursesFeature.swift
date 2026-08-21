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
    /// 서버가 최대 50개만 주므로 넉넉히 요청한다. 총 횟수 필드가 없어 받은 개수로 카운트한다
    static let pageSize = 20

    @ObservableState
    public struct State: Equatable {
        public var courses: [DateSchedule]
        public var hasLoaded: Bool

        public var count: Int { courses.count }

        public init(courses: [DateSchedule] = [], hasLoaded: Bool = false) {
            self.courses = courses
            self.hasLoaded = hasLoaded
        }
    }

    public enum Action: Equatable {
        case onAppear
        case coursesLoaded([DateSchedule])
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
                return .run { [homeClient] send in
                    let courses = (try? await homeClient.pastCourses(Self.pageSize)) ?? []
                    await send(.coursesLoaded(courses))
                }

            case let .coursesLoaded(courses):
                state.courses = courses
                state.hasLoaded = true
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
}
