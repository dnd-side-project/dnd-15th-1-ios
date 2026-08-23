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

    @ObservableState
    public struct State: Equatable {
        public var nickname: String
        public var partnerName: String?
        public var upcomingSchedule: UpcomingSchedule?
        public var recommendations: [Content]
        public var pastSchedules: [DateSchedule]
        public var savedPlaces: [SavedPlace]
        // 요약(GET /home) 로드 완료. 헤더·배너를 이 이후 실제로 그린다
        public var didLoadSummary = false
        // 최근 저장 장소 로드 완료(성공·실패 모두). 로딩과 빈 상태를 구분한다
        public var didLoadSaved = false
        // 추천 로드 완료(성공·실패 모두). 실패해도 스켈레톤을 걷는다
        public var didLoadRecommendations = false

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
            nickname: String = "",
            partnerName: String? = nil,
            upcomingSchedule: UpcomingSchedule? = nil,
            recommendations: [Content] = [],
            pastSchedules: [DateSchedule] = [],
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
        /// 커플 연결이 끝난 뒤 배너·헤더만 다시 받는다
        case reloadRequested
        case homeLoaded(HomeSummary)
        case homeLoadFailed(HomeError)
        case savedPlacesLoaded([SavedPlace])
        case savedPlacesLoadFinished
        case recommendationsLoaded([Content])
        case recommendationsLoadFinished
        case pastDatesLoaded([DateSchedule])
        case placesImported
        case savedPlacesSeeAllTapped
        case savedPlaceTapped(String)
        case calendarTapped
        case connectFlowRequested
        case courseFlowRequested
        case recommendationTapped(String)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case sessionExpired
            case showAllSavedPlaces
            /// 추천 카드 탭. MainTab 이 지도 탭으로 옮겨 상세를 연다
            case showContentDetail(String)
            /// 최근 저장 장소 탭. MainTab 이 지도 탭으로 옮겨 장소 상세를 연다
            case showPlaceDetail(SavedPlace)
            /// 커플 연결 흐름을 연다. 스택은 HomeFlow 가 갖는다
            case connectFlowRequested
            /// 지난 데이트 목록을 연다
            case pastDateCoursesRequested
            /// 코스 짜기를 연다
            case courseFlowRequested
        }
    }

    @Dependency(\.homeClient) var homeClient
    @Dependency(\.exploreClient) var exploreClient
    @Dependency(\.profileClient) var profileClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .merge(loadHome(), loadSavedPlaces(), loadRecommendations())

        case .homeLoaded, .homeLoadFailed, .savedPlacesLoaded, .savedPlacesLoadFinished,
             .recommendationsLoaded, .recommendationsLoadFinished, .pastDatesLoaded:
            return handleLoadResponse(state: &state, action: action)

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

        case .placesImported, .reloadRequested, .calendarTapped, .connectFlowRequested,
             .courseFlowRequested, .delegate:
            return homeNavCore(state: &state, action: action)
        }
    }

    // 요약·저장·추천·지난 데이터의 응답을 모은다. 실패로 끝나도 스켈레톤은 걷는다
    private func handleLoadResponse(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .homeLoaded(summary):
            state.didLoadSummary = true
            state.nickname = summary.myNickname
            state.partnerName = summary.connected ? summary.partnerNickname : nil
            state.upcomingSchedule = summary.currentDateCourse
            // 지난 데이트는 연결됐을 때만 있다
            return summary.connected ? loadPastDates() : .none

        case let .homeLoadFailed(error):
            // 실패해도 스켈레톤은 걷는다. 인증 만료만 상위로 올려 로그인으로 보낸다
            state.didLoadSummary = true
            if error == .unauthorized {
                return .send(.delegate(.sessionExpired))
            }
            return .none

        case let .savedPlacesLoaded(places):
            state.didLoadSaved = true
            state.savedPlaces = places
            return .none

        case .savedPlacesLoadFinished:
            // 실패로 끝나도 스켈레톤은 걷고 기존 데이터는 유지한다
            state.didLoadSaved = true
            return .none

        case let .recommendationsLoaded(contents):
            state.didLoadRecommendations = true
            state.recommendations = contents
            return .none

        case .recommendationsLoadFinished:
            state.didLoadRecommendations = true
            return .none

        case let .pastDatesLoaded(schedules):
            state.pastSchedules = schedules
            return .none

        default:
            return .none
        }
    }

    private func homeNavCore(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .placesImported:
            // 인스타 장소 저장 후 최근 저장 장소·추천 게시글을 새로 받는다
            return .merge(loadSavedPlaces(), loadRecommendations())

        case .reloadRequested:
            return loadHome()

        case .calendarTapped:
            // 연결됐으면 지난 데이트 화면, 아니면 커플 연결로
            guard state.isConnected else { return .send(.connectFlowRequested) }
            return .send(.delegate(.pastDateCoursesRequested))

        case .connectFlowRequested:
            // 이미 연결된 경우 커플 연결로 보내지 않는다
            guard !state.isConnected else { return .none }
            return .send(.delegate(.connectFlowRequested))

        case .courseFlowRequested:
            return .send(.delegate(.courseFlowRequested))

        default:
            return .none
        }
    }
}

// MARK: - 로딩 헬퍼

private extension HomeFeature {
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
            // 실패 시 기존 섹션을 지우지 않도록 데이터는 그대로 두고, 완료만 알려 스켈레톤을 걷는다
            guard let places = try? await homeClient.recentSavedPlaces(Self.recentSavedPlaceCount) else {
                await send(.savedPlacesLoadFinished)
                return
            }
            await send(.savedPlacesLoaded(places))
        }
    }

    private func loadPastDates() -> Effect<Action> {
        .run { [homeClient] send in
            guard let dates = try? await homeClient.pastDates(Self.pastDateCount) else { return }
            await send(.pastDatesLoaded(dates))
        }
    }

    private func loadRecommendations() -> Effect<Action> {
        .run { [profileClient, exploreClient] send in
            // datePreference 를 등록한 사용자만 취향(PREFERENCE) 정렬을 쓰고, 아니면 POPULAR
            let hasPreference = (try? await profileClient.member())?.datePreference != nil
            let sort: ContentSort = hasPreference ? .preference : .popular
            // 실패 시 기존 추천은 그대로 두고, 완료만 알려 스켈레톤을 걷는다
            guard let page = try? await exploreClient.contents(sort, 0, Self.recommendationCount) else {
                await send(.recommendationsLoadFinished)
                return
            }
            await send(.recommendationsLoaded(page.items))
        }
    }
}
