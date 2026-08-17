import Domain
import Foundation
import ThirdParty

@Reducer
public struct HomeFeature {
    /// 커플 연결 세 화면. 모두 `couple` 스토어 하나를 공유하고 Route 로 무엇을 그릴지만 가른다
    public enum CoupleRoute: Hashable {
        case connect
        case codeInput
        case complete
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
        public var couplePath: [CoupleRoute]

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
            upcomingSchedule: UpcomingSchedule? = .mock,
            recommendations: [Content] = Content.mocks,
            pastSchedules: [DateSchedule] = DateSchedule.mocks,
            savedPlaces: [SavedPlace] = [],
            couple: CoupleConnectFeature.State? = nil,
            couplePath: [CoupleRoute] = []
        ) {
            self.nickname = nickname
            self.partnerName = partnerName
            self.upcomingSchedule = upcomingSchedule
            self.recommendations = recommendations
            self.pastSchedules = pastSchedules
            self.savedPlaces = savedPlaces
            self.couple = couple
            self.couplePath = couplePath
        }
    }

    public enum Action: Equatable {
        case onAppear
        case coupleLoaded(CoupleStatus?)
        case coupleLoadFailed(CoupleError)
        case savedPlacesLoaded([SavedPlace])
        case connectFlowRequested
        case couplePathChanged([CoupleRoute])
        case couple(CoupleConnectFeature.Action)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case sessionExpired
        }
    }

    @Dependency(\.placeClient) var placeClient
    @Dependency(\.coupleClient) var coupleClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .ifLet(\.couple, action: \.couple) {
                CoupleConnectFeature()
            }
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .merge(loadCouple(), loadSavedPlaces())

        case let .coupleLoaded(status):
            guard let status else {
                // 성공했지만 커플 없음(404) — 미연결로 확정해 이전 파트너를 지운다
                state.partnerName = nil
                return .none
            }
            state.nickname = status.me.nickname
            state.partnerName = status.connected ? status.partner?.nickname : nil
            return .none

        case let .coupleLoadFailed(error):
            // 인증 만료만 상위로 올려 로그인으로 보내고, 다른 실패는 기존 화면을 유지한다
            if error == .unauthorized {
                return .send(.delegate(.sessionExpired))
            }
            return .none

        case let .savedPlacesLoaded(places):
            state.savedPlaces = places
            return .none

        case .connectFlowRequested:
            // 이미 연결된 경우 커플 연결로 보내지 않는다
            guard !state.isConnected else { return .none }
            state.couple = CoupleConnectFeature.State(myNickname: state.nickname, showsSkip: false)
            state.couplePath = [.connect]
            return .none

        case let .couplePathChanged(path):
            state.couplePath = path
            // 스택이 비면 공유 스토어도 내려 다음 진입이 새 상태로 시작하게 한다
            if path.isEmpty { state.couple = nil }
            return .none

        case let .couple(.delegate(delegate)):
            return handleCoupleDelegate(state: &state, delegate: delegate)

        case .couple, .delegate:
            return .none
        }
    }

    private func handleCoupleDelegate(
        state: inout State,
        delegate: CoupleConnectFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case .showCodeInput:
            state.couplePath.append(.codeInput)
            return .none
        case .showComplete:
            state.couplePath.append(.complete)
            return .none
        case .back:
            guard !state.couplePath.isEmpty else { return .none }
            state.couplePath.removeLast()
            if state.couplePath.isEmpty { state.couple = nil }
            return .none
        case .connected, .skipped:
            // 홈 진입엔 skip 이 없지만 방어적으로 같이 닫고 배너·헤더를 새로 받는다
            state.couple = nil
            state.couplePath = []
            return loadCouple()
        case .sessionExpired:
            state.couple = nil
            state.couplePath = []
            return .send(.delegate(.sessionExpired))
        }
    }

    private func loadCouple() -> Effect<Action> {
        .run { [coupleClient] send in
            do {
                let status = try await coupleClient.current()
                await send(.coupleLoaded(status))
            } catch let error as CoupleError {
                await send(.coupleLoadFailed(error))
            } catch {
                await send(.coupleLoadFailed(.unknown))
            }
        }
    }

    private func loadSavedPlaces() -> Effect<Action> {
        .run { [placeClient] send in
            let places = (try? await placeClient.savedPlaces()) ?? []
            await send(.savedPlacesLoaded(places))
        }
    }
}
