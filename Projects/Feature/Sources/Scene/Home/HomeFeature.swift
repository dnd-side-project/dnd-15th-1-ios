import Domain
import Foundation
import ThirdParty

@Reducer
public struct HomeFeature {
    /// 추천 섹션에 보여줄 게시물 수
    static let recommendationCount = 10

    /// 최근 저장 장소 미리보기 수
    static let recentSavedPlaceCount = 5

    /// 지난 데이트 미리보기 수
    static let pastDateCount = 3

    /// 홈에서 push 되는 화면. 커플 세 화면은 `couple` 스토어를 공유, 지난 데이트는 별도 스토어,
    /// 코스 짜기 두 화면은 `course` 스토어를 공유한다
    public enum HomeRoute: Hashable {
        case connect
        case codeInput
        case complete
        case pastDateCourses
        case course
        case coursePlacePick

        var isCouple: Bool {
            switch self {
            case .connect, .codeInput, .complete: return true
            case .pastDateCourses, .course, .coursePlacePick: return false
            }
        }

        var isCourse: Bool {
            self == .course || self == .coursePlacePick
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var nickname: String
        public var partnerName: String?
        public var upcomingSchedule: UpcomingSchedule?
        public var recommendations: [Content]
        public var pastSchedules: [DateSchedule]
        public var savedPlaces: [SavedPlace]
        public var couple: CoupleConnectFeature.State?
        public var pastDateCourses: PastDateCoursesFeature.State?
        public var course: CourseFeature.State?
        public var homePath: [HomeRoute]

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
            partnerName: String? = nil,
            upcomingSchedule: UpcomingSchedule? = nil,
            recommendations: [Content] = [],
            pastSchedules: [DateSchedule] = [],
            savedPlaces: [SavedPlace] = [],
            couple: CoupleConnectFeature.State? = nil,
            pastDateCourses: PastDateCoursesFeature.State? = nil,
            course: CourseFeature.State? = nil,
            homePath: [HomeRoute] = []
        ) {
            self.nickname = nickname
            self.partnerName = partnerName
            self.upcomingSchedule = upcomingSchedule
            self.recommendations = recommendations
            self.pastSchedules = pastSchedules
            self.savedPlaces = savedPlaces
            self.couple = couple
            self.pastDateCourses = pastDateCourses
            self.course = course
            self.homePath = homePath
        }
    }

    public enum Action: Equatable {
        case onAppear
        case homeLoaded(HomeSummary)
        case homeLoadFailed(HomeError)
        case savedPlacesLoaded([SavedPlace])
        case recommendationsLoaded([Content])
        case pastDatesLoaded([DateSchedule])
        case savedPlacesSeeAllTapped
        case savedPlaceTapped(String)
        case calendarTapped
        case connectFlowRequested
        case courseFlowRequested
        case recommendationTapped(String)
        case homePathChanged([HomeRoute])
        case couple(CoupleConnectFeature.Action)
        case pastDateCourses(PastDateCoursesFeature.Action)
        case course(CourseFeature.Action)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case sessionExpired
            case showAllSavedPlaces
            /// 추천 카드 탭. MainTab 이 지도 탭으로 옮겨 상세를 연다
            case showContentDetail(String)
            /// 최근 저장 장소 탭. MainTab 이 지도 탭으로 옮겨 장소 상세를 연다
            case showPlaceDetail(SavedPlace)
        }
    }

    @Dependency(\.homeClient) var homeClient
    @Dependency(\.exploreClient) var exploreClient
    @Dependency(\.profileClient) var profileClient

    public init() {}

    public var body: some ReducerOf<Self> {
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
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .merge(loadHome(), loadSavedPlaces(), loadRecommendations())

        case let .homeLoaded(summary):
            state.nickname = summary.myNickname
            state.partnerName = summary.connected ? summary.partnerNickname : nil
            state.upcomingSchedule = summary.currentDateCourse
            // 지난 데이트는 연결됐을 때만 있다
            return summary.connected ? loadPastDates() : .none

        case let .homeLoadFailed(error):
            // 인증 만료만 상위로 올려 로그인으로 보내고, 다른 실패는 기존 화면을 유지한다
            if error == .unauthorized {
                return .send(.delegate(.sessionExpired))
            }
            return .none

        case let .savedPlacesLoaded(places):
            state.savedPlaces = places
            return .none

        case let .recommendationsLoaded(contents):
            state.recommendations = contents
            return .none

        case let .pastDatesLoaded(schedules):
            state.pastSchedules = schedules
            return .none

        case .savedPlacesSeeAllTapped:
            // 전체보기는 지도 탭으로 이동. 실제 탭 전환은 상위(MainTab)가 처리
            return .send(.delegate(.showAllSavedPlaces))

        case let .savedPlaceTapped(id):
            // 장소 상세는 지도 탭에서 연다. 전체보기와 같은 길
            guard let place = state.savedPlaces.first(where: { $0.id == id }) else { return .none }
            return .send(.delegate(.showPlaceDetail(place)))

        case let .recommendationTapped(id):
            // 표시는 지도 탭 위에서. MainTab 까지 올린다
            return .send(.delegate(.showContentDetail(id)))

        case .calendarTapped, .connectFlowRequested, .courseFlowRequested, .homePathChanged,
             .couple, .pastDateCourses, .course, .delegate:
            return homeNavCore(state: &state, action: action)
        }
    }

    private func homeNavCore(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .calendarTapped:
            // 연결됐으면 지난 데이트 화면, 아니면 커플 연결로
            guard state.isConnected else { return .send(.connectFlowRequested) }
            state.pastDateCourses = PastDateCoursesFeature.State()
            state.homePath.append(.pastDateCourses)
            return .none

        case .connectFlowRequested:
            // 이미 연결된 경우 커플 연결로 보내지 않는다
            guard !state.isConnected else { return .none }
            state.couple = CoupleConnectFeature.State(myNickname: state.nickname, showsSkip: false)
            state.homePath = [.connect]
            return .none

        case .courseFlowRequested:
            // 지난 진입의 날짜·장소를 물려받지 않게 새 상태로 연다
            state.course = CourseFeature.State()
            state.homePath.append(.course)
            return .none

        case let .homePathChanged(path):
            applyHomePath(path, state: &state)
            return .none

        case let .couple(.delegate(delegate)):
            return handleCoupleDelegate(state: &state, delegate: delegate)

        case let .pastDateCourses(.delegate(delegate)):
            return handlePastDelegate(state: &state, delegate: delegate)

        case let .course(.delegate(delegate)):
            return handleCourseDelegate(state: &state, delegate: delegate)

        default:
            return .none
        }
    }
}

// MARK: - 네비게이션 · 로딩 헬퍼

private extension HomeFeature {
    /// 스택에서 빠진 화면의 스토어를 내려 다음 진입이 새 상태로 시작하게 한다
    func applyHomePath(_ path: [HomeRoute], state: inout State) {
        state.homePath = path
        if !path.contains(.pastDateCourses) { state.pastDateCourses = nil }
        if !path.contains(where: \.isCouple) { state.couple = nil }
        if !path.contains(where: \.isCourse) { state.course = nil }
    }

    func handleCourseDelegate(
        state: inout State,
        delegate: CourseFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case .placePickRequested:
            state.homePath.append(.coursePlacePick)
            return .none
        case .dismissed:
            var next = state.homePath
            // 코스 화면이 스스로 닫는 신호라, 맨 위가 코스 경로일 때만 뺀다
            if let last = next.last, last.isCourse {
                next.removeLast()
            }
            return .send(.homePathChanged(next))
        case .buildRequested:
            // 코스 결과 화면은 아직 없음
            return .none
        case .sessionExpired:
            state.course = nil
            state.homePath = []
            return .send(.delegate(.sessionExpired))
        }
    }

    private func handlePastDelegate(
        state: inout State,
        delegate: PastDateCoursesFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case .back:
            if !state.homePath.isEmpty { state.homePath.removeLast() }
            state.pastDateCourses = nil
            return .none
        case .createCourse:
            // 지난 데이트 위로 코스 짜기를 밀어 뒤로가기 시 지난 데이트로 돌아오게 한다
            return .send(.courseFlowRequested)
        }
    }

    private func handleCoupleDelegate(
        state: inout State,
        delegate: CoupleConnectFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case .showCodeInput:
            state.homePath.append(.codeInput)
            return .none
        case .showComplete:
            state.homePath.append(.complete)
            return .none
        case .back:
            guard !state.homePath.isEmpty else { return .none }
            state.homePath.removeLast()
            if state.homePath.isEmpty { state.couple = nil }
            return .none
        case .connected, .skipped:
            // 홈 진입엔 skip 이 없지만 방어적으로 같이 닫고 배너·헤더를 새로 받는다
            state.couple = nil
            state.homePath = []
            return loadHome()
        case .sessionExpired:
            state.couple = nil
            state.homePath = []
            return .send(.delegate(.sessionExpired))
        }
    }

    private func loadHome() -> Effect<Action> {
        .run { [homeClient] send in
            do {
                let summary = try await homeClient.home()
                await send(.homeLoaded(summary))
            } catch let error as HomeError {
                await send(.homeLoadFailed(error))
            } catch {
                await send(.homeLoadFailed(.unknown))
            }
        }
    }

    private func loadSavedPlaces() -> Effect<Action> {
        .run { [homeClient] send in
            let places = (try? await homeClient.recentSavedPlaces(Self.recentSavedPlaceCount)) ?? []
            await send(.savedPlacesLoaded(places))
        }
    }

    private func loadPastDates() -> Effect<Action> {
        .run { [homeClient] send in
            let dates = (try? await homeClient.pastDates(Self.pastDateCount)) ?? []
            await send(.pastDatesLoaded(dates))
        }
    }

    private func loadRecommendations() -> Effect<Action> {
        .run { [profileClient, exploreClient] send in
            // datePreference 를 등록한 사용자만 취향(PREFERENCE) 정렬을 쓰고, 아니면 POPULAR
            let hasPreference = (try? await profileClient.member())?.datePreference != nil
            let sort: ContentSort = hasPreference ? .preference : .popular
            let page = try? await exploreClient.contents(sort, 0, Self.recommendationCount)
            await send(.recommendationsLoaded(page?.items ?? []))
        }
    }
}
