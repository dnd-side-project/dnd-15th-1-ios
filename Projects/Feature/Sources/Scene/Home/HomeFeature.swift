import Domain
import Foundation
import SharedDesignSystem
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
        public var upcomingSchedule: DateCourseSummary?
        public var recommendations: [Content]
        public var pastSchedules: [DateCourseSummary]
        public var savedPlaces: [SavedPlace]
        /// 당겨서 새로고침 중인지. 실패 알림을 이때만 낸다
        public var isRefreshing = false
        public var toast: ToastState?
        // 요약(커플·회원 조회, 연결됐으면 현재 코스까지) 로드 완료. 헤더·배너를 이 이후 실제로 그린다
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

        public var visiblePastSchedules: [DateCourseSummary] {
            Array(pastSchedules.prefix(3))
        }

        public var visibleSavedPlaces: [SavedPlace] {
            Array(savedPlaces.prefix(5))
        }

        public init(
            nickname: String = "",
            partnerName: String? = nil,
            upcomingSchedule: DateCourseSummary? = nil,
            recommendations: [Content] = [],
            pastSchedules: [DateCourseSummary] = [],
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
        /// 사용자가 화면을 당겼다. onAppear 와 같은 것을 읽는다
        case refreshRequested
        case refreshFinished
        case refreshFailed
        case toastDismissed
        /// 커플 연결이 끝난 뒤 배너·헤더만 다시 받는다
        case reloadRequested
        /// 커플·회원 조회가 둘 다 끝났다. 연결됐으면 현재 코스가 뒤따른다
        case summaryLoaded(profile: UserProfile, couple: CoupleStatus)
        /// 커플·회원 조회 중 하나라도 실패했다. 인증 만료면 참이다
        case summaryLoadFailed(isSessionExpired: Bool)
        case currentCourseLoaded(DateCourseSummary?)
        case currentCourseLoadFailed
        case savedPlacesLoaded([SavedPlace])
        case savedPlacesLoadFinished
        case recommendationsLoaded([Content])
        case recommendationsLoadFinished
        case pastDatesLoaded([DateCourseSummary])
        case placesImported
        case savedPlacesSeeAllTapped
        case savedPlaceTapped(String)
        case calendarTapped
        case connectFlowRequested
        case courseFlowRequested
        case bannerTapped
        case pastScheduleTapped(String)
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
            /// 예정 코스(배너) 또는 지난 데이트 결과를 연다
            case showCourseResult(dateCourseID: String, origin: CourseResultFeature.State.Origin)
        }
    }

    @Dependency(\.coupleClient) var coupleClient
    @Dependency(\.profileClient) var profileClient
    @Dependency(\.courseClient) var courseClient
    @Dependency(\.placeClient) var placeClient
    @Dependency(\.contentClient) var contentClient
    @Dependency(\.analyticsClient) var analyticsClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .merge(loadSummary(), loadSavedPlaces(), loadRecommendations())

        case .refreshRequested, .refreshFinished, .refreshFailed, .toastDismissed:
            return homeRefreshCore(state: &state, action: action)

        case .summaryLoaded, .summaryLoadFailed, .currentCourseLoaded, .currentCourseLoadFailed:
            return handleSummaryResponse(state: &state, action: action)

        case .savedPlacesLoaded, .savedPlacesLoadFinished,
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

        case let .pastScheduleTapped(id):
            // 지난 데이트라 수정·알리기를 숨긴다
            guard state.pastSchedules.contains(where: { $0.id == id }) else { return .none }
            return .send(.delegate(.showCourseResult(dateCourseID: id, origin: .pastDate)))

        case .placesImported, .reloadRequested, .calendarTapped, .connectFlowRequested,
             .courseFlowRequested, .bannerTapped, .delegate:
            return homeNavCore(state: &state, action: action)
        }
    }

    // 저장·추천·지난 데이터의 응답을 모은다. 실패로 끝나도 스켈레톤은 걷는다
    private func handleLoadResponse(state: inout State, action: Action) -> Effect<Action> {
        switch action {
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

    private func homeRefreshCore(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .refreshRequested:
            state.isRefreshing = true
            return .merge(
                loadSummary(),
                loadSavedPlaces(notifiesFailure: true),
                loadRecommendations(notifiesFailure: true)
            )

        case .refreshFinished:
            state.isRefreshing = false
            return .none

        case .refreshFailed:
            // 여럿이 다 실패해도 토스트는 하나다
            if state.toast == nil {
                state.toast = ToastState(message: "잠시 뒤 다시 시도해주세요")
            }
            return .none

        case .toastDismissed:
            state.toast = nil
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
            return loadSummary()

        case .calendarTapped:
            // 연결됐으면 지난 데이트 화면, 아니면 커플 연결로
            guard state.isConnected else { return .send(.connectFlowRequested) }
            return .send(.delegate(.pastDateCoursesRequested))

        case .connectFlowRequested:
            // 이미 연결된 경우 커플 연결로 보내지 않는다
            guard !state.isConnected else { return .none }
            return .send(.delegate(.connectFlowRequested))

        case .courseFlowRequested:
            return .merge(
                .run { [analyticsClient] _ in
                    await analyticsClient.track(.courseCreateStarted(entryPoint: .homeBanner))
                },
                .send(.delegate(.courseFlowRequested))
            )

        case .bannerTapped:
            guard let id = state.upcomingSchedule?.id else { return .none }
            return .merge(
                .run { [analyticsClient] _ in
                    await analyticsClient.track(.courseViewed(entryPoint: .homeBanner))
                },
                .send(.delegate(.showCourseResult(dateCourseID: id, origin: .courseBuilt)))
            )

        default:
            return .none
        }
    }
}

// MARK: - 요약

private extension HomeFeature {
    func handleSummaryResponse(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .summaryLoaded(profile, couple):
            state.nickname = profile.nickname
            guard case let .connected(_, partner, _) = couple else {
                state.partnerName = nil
                state.upcomingSchedule = nil
                state.didLoadSummary = true
                return .none
            }
            state.partnerName = partner.nickname
            // 헤더·배너는 현재 코스까지 받은 뒤 켠다. 먼저 켜면 코스 짜기 배너가 잠깐 뜬다.
            // 지난 데이트는 연결됐을 때만 있다
            return .merge(
                loadCurrentCourse(),
                loadPastDates(notifiesFailure: state.isRefreshing)
            )

        case let .summaryLoadFailed(isSessionExpired):
            // 실패해도 스켈레톤은 걷는다. 인증 만료만 상위로 올려 로그인으로 보낸다
            state.didLoadSummary = true
            if isSessionExpired {
                return .send(.delegate(.sessionExpired))
            }
            return state.isRefreshing ? .send(.refreshFailed) : .none

        case let .currentCourseLoaded(course):
            state.upcomingSchedule = course
            state.didLoadSummary = true
            return .none

        case .currentCourseLoadFailed:
            // 이전 배너를 둔다. 처음 열 때 실패면 비어 있어 코스 짜기 배너가 뜬다
            state.didLoadSummary = true
            return state.isRefreshing ? .send(.refreshFailed) : .none

        default:
            return .none
        }
    }

    /// 커플·회원 조회를 한 묶음으로 부른다. 둘 중 하나라도 실패하면 요약 실패다
    func loadSummary() -> Effect<Action> {
        .run { [coupleClient, profileClient] send in
            do {
                async let couple = coupleClient.current()
                async let profile = profileClient.member()
                let loaded = try await (profile, couple)
                await send(.summaryLoaded(profile: loaded.0, couple: loaded.1))
            } catch {
                await send(.summaryLoadFailed(isSessionExpired: Self.isSessionExpired(error)))
            }
        }
    }

    /// 인증 만료는 커플·회원 두 창구의 에러만 본다. 현재 코스 실패는 요약 실패가 아니다
    static func isSessionExpired(_ error: Error) -> Bool {
        (error as? CoupleError) == .unauthorized || (error as? ProfileError) == .unauthorized
    }

    /// 연결됐을 때만 부른다. 날짜 읽기 실패와 다른 실패를 가를 수 없어 모두 같은 실패로 받는다
    func loadCurrentCourse() -> Effect<Action> {
        .run { [courseClient] send in
            do {
                await send(.currentCourseLoaded(try await courseClient.currentCourse()))
            } catch {
                await send(.currentCourseLoadFailed)
            }
        }
    }
}

// MARK: - 로딩 헬퍼

private extension HomeFeature {
    private func loadSavedPlaces(notifiesFailure: Bool = false) -> Effect<Action> {
        .run { [placeClient] send in
            // 실패 시 기존 섹션을 지우지 않도록 데이터는 그대로 두고, 완료만 알려 스켈레톤을 걷는다
            guard let places = try? await placeClient.recentSavedPlaces(Self.recentSavedPlaceCount) else {
                await send(.savedPlacesLoadFinished)
                if notifiesFailure { await send(.refreshFailed) }
                return
            }
            await send(.savedPlacesLoaded(places))
        }
    }

    private func loadPastDates(notifiesFailure: Bool = false) -> Effect<Action> {
        .run { [courseClient] send in
            guard let dates = try? await courseClient.latestPastCourses(Self.pastDateCount) else {
                if notifiesFailure { await send(.refreshFailed) }
                return
            }
            await send(.pastDatesLoaded(dates))
        }
    }

    private func loadRecommendations(notifiesFailure: Bool = false) -> Effect<Action> {
        .run { [profileClient, contentClient] send in
            // datePreference 를 등록한 사용자만 취향(PREFERENCE) 정렬을 쓰고, 아니면 POPULAR
            let hasPreference = (try? await profileClient.member())?.datePreference != nil
            let sort: ContentSort = hasPreference ? .preference : .popular
            // 실패 시 기존 추천은 그대로 두고, 완료만 알려 스켈레톤을 걷는다
            guard let feed = try? await contentClient.contents(sort, 0, Self.recommendationCount) else {
                await send(.recommendationsLoadFinished)
                if notifiesFailure { await send(.refreshFailed) }
                return
            }
            await send(.recommendationsLoaded(feed.page.items))
        }
    }
}
