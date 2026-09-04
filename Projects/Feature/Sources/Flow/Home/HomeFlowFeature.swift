import Domain
import Foundation
import ThirdParty

/// 홈 탭의 화면 스택. 홈이 root 이고 목적지 화면이 그 위로 쌓인다.
///
/// 화면을 안 그린다. 경로와 자식만 갖는다
@Reducer
public struct HomeFlowFeature {
    /// 홈(root) 위로 쌓이는 화면. 커플 세 화면은 `couple` 스토어를 공유,
    /// 지난 데이트는 별도 스토어, 코스 짜기 두 화면은 `course` 스토어를 공유한다.
    /// 수정은 `courseEdit`, 장소 추가는 `coursePlaceAdd` 가 따로 갖는다
    public enum Route: Hashable {
        case connect
        case codeInput
        case complete
        case pastDateCourses
        case course
        case coursePlacePick
        case courseResult
        case courseEdit
        case coursePlaceAdd

        var isCouple: Bool {
            switch self {
            case .connect, .codeInput, .complete: return true
            case .pastDateCourses, .course, .coursePlacePick, .courseResult,
                 .courseEdit, .coursePlaceAdd: return false
            }
        }

        var isCourse: Bool {
            self == .course || self == .coursePlacePick
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var home: HomeFeature.State
        public var couple: CoupleConnectFeature.State?
        public var pastDateCourses: PastDateCoursesFeature.State?
        public var course: CourseFeature.State?
        public var courseResult: CourseResultFeature.State?
        public var courseEdit: CourseEditFeature.State?
        public var coursePlaceAdd: CourseFeature.State?
        public var path: [Route]

        public init(
            home: HomeFeature.State = HomeFeature.State(),
            couple: CoupleConnectFeature.State? = nil,
            pastDateCourses: PastDateCoursesFeature.State? = nil,
            course: CourseFeature.State? = nil,
            courseResult: CourseResultFeature.State? = nil,
            courseEdit: CourseEditFeature.State? = nil,
            coursePlaceAdd: CourseFeature.State? = nil,
            path: [Route] = []
        ) {
            self.home = home
            self.couple = couple
            self.pastDateCourses = pastDateCourses
            self.course = course
            self.courseResult = courseResult
            self.courseEdit = courseEdit
            self.coursePlaceAdd = coursePlaceAdd
            self.path = path
        }
    }

    public enum Action: Equatable {
        case pathChanged([Route])
        /// 인스타 장소 저장 뒤 홈이 데이터를 다시 받게 한다. RootFlow 가 부른다
        case placesImported
        case home(HomeFeature.Action)
        case couple(CoupleConnectFeature.Action)
        case pastDateCourses(PastDateCoursesFeature.Action)
        case course(CourseFeature.Action)
        case courseResult(CourseResultFeature.Action)
        case courseEdit(CourseEditFeature.Action)
        case coursePlaceAdd(CourseFeature.Action)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 세션 만료. RootFlow 까지 올라가 로그인으로 되돌린다
            case sessionExpired
            case showAllSavedPlaces
            /// 추천 카드 탭. MainTab 이 지도 탭으로 옮겨 상세를 연다
            case showContentDetail(String)
            /// 최근 저장 장소 탭. MainTab 이 지도 탭으로 옮겨 장소 상세를 연다
            case showPlaceDetail(SavedPlace)
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Reduce(core)
            .ifLet(\.couple, action: \.couple) {
                CoupleConnectFeature()
            }
            .ifLet(\.pastDateCourses, action: \.pastDateCourses) {
                PastDateCoursesFeature()
            }
            .ifLet(\.course, action: \.course) {
                CourseFeature()
            }
            .ifLet(\.courseResult, action: \.courseResult) {
                CourseResultFeature()
            }
            .ifLet(\.courseEdit, action: \.courseEdit) {
                CourseEditFeature()
            }
            .ifLet(\.coursePlaceAdd, action: \.coursePlaceAdd) {
                CourseFeature()
            }
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .pathChanged(path):
            return applyPath(path, state: &state)

        case .placesImported:
            return .send(.home(.placesImported))

        case let .home(.delegate(delegate)):
            return handle(homeDelegate: delegate, state: &state)

        case let .couple(.delegate(delegate)):
            return handle(coupleDelegate: delegate, state: &state)

        case let .pastDateCourses(.delegate(delegate)):
            return handle(pastDelegate: delegate, state: &state)

        case let .course(.delegate(delegate)):
            return handle(courseDelegate: delegate, state: &state)

        case let .courseResult(.delegate(delegate)):
            return handle(courseResultDelegate: delegate, state: &state)

        case let .courseEdit(.delegate(delegate)):
            return handle(courseEditDelegate: delegate, state: &state)

        case let .coursePlaceAdd(.delegate(delegate)):
            return handle(coursePlaceAddDelegate: delegate, state: &state)

        case .home, .couple, .pastDateCourses, .course, .courseResult,
             .courseEdit, .coursePlaceAdd, .delegate:
            return .none
        }
    }
}

private extension HomeFlowFeature {
    /// 스택에서 빠진 화면의 스토어를 내려 다음 진입이 새 상태로 시작하게 한다
    func applyPath(_ path: [Route], state: inout State) -> Effect<Action> {
        let leftCourseResult = state.path.contains(.courseResult) && !path.contains(.courseResult)
        state.path = path
        if !path.contains(.pastDateCourses) { state.pastDateCourses = nil }
        if !path.contains(where: \.isCouple) { state.couple = nil }
        if !path.contains(where: \.isCourse) { state.course = nil }
        if !path.contains(.courseResult) { state.courseResult = nil }
        if !path.contains(.courseEdit) { state.courseEdit = nil }
        if !path.contains(.coursePlaceAdd) { state.coursePlaceAdd = nil }
        guard leftCourseResult else { return .none }
        return .send(.home(.reloadRequested))
    }

    /// 지난 진입의 날짜·장소를 물려받지 않게 새 상태로 연다
    func openCourse(state: inout State) -> Effect<Action> {
        state.course = CourseFeature.State()
        return applyPath(state.path + [.course], state: &state)
    }

    func handle(
        homeDelegate: HomeFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch homeDelegate {
        case .connectFlowRequested:
            state.couple = CoupleConnectFeature.State(
                myNickname: state.home.nickname,
                showsSkip: false
            )
            return applyPath([.connect], state: &state)

        case .pastDateCoursesRequested:
            state.pastDateCourses = PastDateCoursesFeature.State(
                hasCurrentCourse: state.home.upcomingSchedule != nil
            )
            return applyPath(state.path + [.pastDateCourses], state: &state)

        case .courseFlowRequested:
            return openCourse(state: &state)

        case let .showCourseResult(dateCourseID, origin):
            // 코스를 안 실어 보낸다. 결과 화면이 onAppear 에서 스스로 조회한다
            state.courseResult = CourseResultFeature.State(
                course: nil,
                dateCourseID: dateCourseID,
                partnerNickname: state.home.partnerName,
                origin: origin
            )
            return applyPath(state.path + [.courseResult], state: &state)

        case .sessionExpired:
            return .send(.delegate(.sessionExpired))

        case .showAllSavedPlaces:
            return .send(.delegate(.showAllSavedPlaces))

        case let .showContentDetail(id):
            return .send(.delegate(.showContentDetail(id)))

        case let .showPlaceDetail(place):
            return .send(.delegate(.showPlaceDetail(place)))
        }
    }

    func handle(
        coupleDelegate: CoupleConnectFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch coupleDelegate {
        case .showCodeInput:
            return applyPath(state.path + [.codeInput], state: &state)
        case .showComplete:
            return applyPath(state.path + [.complete], state: &state)
        case .back:
            guard !state.path.isEmpty else { return .none }
            var next = state.path
            next.removeLast()
            return applyPath(next, state: &state)
        case .connected, .skipped:
            // 홈 진입엔 skip 이 없지만 방어적으로 같이 닫고 배너·헤더를 새로 받는다
            return .concatenate(
                applyPath([], state: &state),
                .send(.home(.reloadRequested))
            )
        case .sessionExpired:
            return .concatenate(
                applyPath([], state: &state),
                .send(.delegate(.sessionExpired))
            )
        }
    }

    func handle(
        pastDelegate: PastDateCoursesFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch pastDelegate {
        case .back:
            var next = state.path
            if !next.isEmpty { next.removeLast() }
            return applyPath(next, state: &state)
        case .createCourse:
            // 지난 데이트 위로 코스 짜기를 밀어 뒤로가기 시 지난 데이트로 돌아오게 한다
            return openCourse(state: &state)
        case let .courseSelected(dateCourseID):
            // 코스를 안 실어 보낸다. 결과 화면이 onAppear 에서 스스로 조회한다
            state.courseResult = CourseResultFeature.State(
                course: nil,
                dateCourseID: dateCourseID,
                partnerNickname: state.home.partnerName,
                origin: .pastDate
            )
            return applyPath(state.path + [.courseResult], state: &state)
        }
    }

    func handle(
        courseDelegate: CourseFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch courseDelegate {
        case .placePickRequested:
            return applyPath(state.path + [.coursePlacePick], state: &state)
        case .placesPicked:
            // 만들기 모드는 이 신호를 안 쏜다. 고르기는 coursePlaceAdd 가 받는다
            return .none
        case .dismissed:
            var next = state.path
            // 코스 화면이 스스로 닫는 신호라, 맨 위가 코스 경로일 때만 뺀다
            if let last = next.last, last.isCourse {
                next.removeLast()
            }
            return .send(.pathChanged(next))
        case let .buildRequested(course):
            state.courseResult = CourseResultFeature.State(
                course: course,
                dateCourseID: course.id,
                partnerNickname: state.course?.partnerNickname
            )
            return applyPath(state.path + [.courseResult], state: &state)
        case .sessionExpired:
            return .concatenate(
                applyPath([], state: &state),
                .send(.delegate(.sessionExpired))
            )
        }
    }

    func handle(
        courseResultDelegate: CourseResultFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch courseResultDelegate {
        case .dismissed:
            var next = state.path
            // 코스·결과 꼬리만 벗긴다. 그 아래(지난 데이트 목록 등)는 그대로 둔다
            while let last = next.last, last.isCourse || last == .courseResult {
                next.removeLast()
            }
            return .send(.pathChanged(next))
        case let .editRequested(course):
            state.courseEdit = CourseEditFeature.State(dateCourseID: course.id)
            state.path.append(.courseEdit)
            return .none
        case .sessionExpired:
            return .concatenate(
                applyPath([], state: &state),
                .send(.delegate(.sessionExpired))
            )
        }
    }

    func handle(
        courseEditDelegate: CourseEditFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch courseEditDelegate {
        case let .placeAddRequested(excluding):
            state.coursePlaceAdd = CourseFeature.State(mode: .pick(excluding: excluding))
            state.path.append(.coursePlaceAdd)
            return .none

        case let .saved(course):
            // PUT 응답이 최신 코스라 결과 화면이 서버를 다시 부르지 않는다
            var next = state.path
            if next.last == .courseEdit {
                next.removeLast()
            }
            return .concatenate(
                .send(.pathChanged(next)),
                .send(.courseResult(.courseResponse(.success(course))))
            )

        case .dismissed:
            var next = state.path
            if next.last == .courseEdit {
                next.removeLast()
            }
            return .send(.pathChanged(next))

        case .conflicted:
            var next = state.path
            if next.last == .courseEdit {
                next.removeLast()
            }
            return .concatenate(
                .send(.pathChanged(next)),
                .send(.courseResult(.conflictReloadRequested))
            )

        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        }
    }

    func handle(
        coursePlaceAddDelegate: CourseFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch coursePlaceAddDelegate {
        case let .placesPicked(candidates):
            var next = state.path
            if next.last == .coursePlaceAdd {
                next.removeLast()
            }
            return .concatenate(
                .send(.pathChanged(next)),
                .send(.courseEdit(.placesAdded(candidates)))
            )
        case .dismissed:
            var next = state.path
            if next.last == .coursePlaceAdd {
                next.removeLast()
            }
            return .send(.pathChanged(next))
        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        case .placePickRequested, .buildRequested:
            return .none
        }
    }
}
