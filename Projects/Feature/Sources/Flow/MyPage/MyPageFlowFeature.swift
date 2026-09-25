import Domain
import Foundation
import ThirdParty

/// 마이 탭의 화면 스택. 마이페이지가 root 이고 목적지 화면이 그 위로 쌓인다.
///
/// 화면을 안 그린다. 경로와 자식만 갖는다
@Reducer
public struct MyPageFlowFeature {
    /// 마이페이지(root) 위로 쌓이는 화면. 커플 세 화면은 `couple` 스토어를 공유한다
    public enum Route: Hashable {
        case noticeList
        case noticeDetail
        case dateType
        case connection
        // 미연결 상태에서 타는 커플 연결 플로우
        case connect
        case codeInput
        case complete

        var isCouple: Bool {
            self == .connect || self == .codeInput || self == .complete
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var myPage: MyPageFeature.State
        public var path: [Route]
        public var dateType: DateTypeFeature.State?
        public var connection: ConnectionManageFeature.State?
        public var couple: CoupleConnectFeature.State?
        public var noticeList: NoticeListFeature.State?
        public var noticeDetail: NoticeDetailFeature.State?

        /// 회원탈퇴 모달은 탭뷰가 띄운다. 탭뷰가 자식까지 파고들지 않게 여기서 비춘다
        public var isWithdrawModalPresented: Bool {
            myPage.isWithdrawModalPresented
        }

        public init(
            myPage: MyPageFeature.State = MyPageFeature.State(),
            path: [Route] = [],
            dateType: DateTypeFeature.State? = nil,
            connection: ConnectionManageFeature.State? = nil,
            couple: CoupleConnectFeature.State? = nil,
            noticeList: NoticeListFeature.State? = nil,
            noticeDetail: NoticeDetailFeature.State? = nil
        ) {
            self.myPage = myPage
            self.path = path
            self.dateType = dateType
            self.connection = connection
            self.couple = couple
            self.noticeList = noticeList
            self.noticeDetail = noticeDetail
        }
    }

    public enum Action: Equatable {
        case pathChanged([Route])
        case myPage(MyPageFeature.Action)
        case dateType(DateTypeFeature.Action)
        case connection(ConnectionManageFeature.Action)
        case couple(CoupleConnectFeature.Action)
        case noticeList(NoticeListFeature.Action)
        case noticeDetail(NoticeDetailFeature.Action)
        // 탈퇴 모달은 탭바까지 덮어야 해서 탭뷰가 띄운다. 그 두 신호를 받아 아래로 넘긴다
        case withdrawConfirmed
        case dismissWithdrawModal
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case logoutSucceeded
            case accountWithdrawn
            case sessionExpired
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.myPage, action: \.myPage) {
            MyPageFeature()
        }
        Reduce(core)
            .ifLet(\.dateType, action: \.dateType) {
                DateTypeFeature()
            }
            .ifLet(\.connection, action: \.connection) {
                ConnectionManageFeature()
            }
            .ifLet(\.couple, action: \.couple) {
                CoupleConnectFeature()
            }
            .ifLet(\.noticeList, action: \.noticeList) {
                NoticeListFeature()
            }
            .ifLet(\.noticeDetail, action: \.noticeDetail) {
                NoticeDetailFeature()
            }
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .pathChanged(path):
            return applyPath(path, state: &state)

        case .withdrawConfirmed:
            return .send(.myPage(.withdrawConfirmed))

        case .dismissWithdrawModal:
            return .send(.myPage(.dismissWithdrawModal))

        case let .myPage(.delegate(delegate)):
            return handle(myPageDelegate: delegate, state: &state)

        case let .dateType(.delegate(delegate)):
            return handle(dateTypeDelegate: delegate, state: &state)

        case let .connection(.delegate(delegate)):
            return handle(connectionDelegate: delegate, state: &state)

        case let .couple(.delegate(delegate)):
            return handle(coupleDelegate: delegate, state: &state)

        case let .noticeList(.delegate(delegate)):
            return handle(noticeListDelegate: delegate, state: &state)

        case let .noticeDetail(.delegate(delegate)):
            return handle(noticeDetailDelegate: delegate, state: &state)

        case .myPage, .dateType, .connection, .couple,
             .noticeList, .noticeDetail, .delegate:
            return .none
        }
    }
}

private extension MyPageFlowFeature {
    /// 스택에서 빠진 화면의 스토어를 내려 다음 진입이 새 상태로 시작하게 한다
    func applyPath(_ path: [Route], state: inout State) -> Effect<Action> {
        state.path = path
        if !path.contains(.dateType) { state.dateType = nil }
        if !path.contains(.connection) { state.connection = nil }
        if !path.contains(where: \.isCouple) { state.couple = nil }
        if !path.contains(.noticeList) { state.noticeList = nil }
        if !path.contains(.noticeDetail) { state.noticeDetail = nil }
        return .none
    }

    func handle(
        myPageDelegate: MyPageFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch myPageDelegate {
        case let .dateTypeRequested(preference):
            // 현재 데이트 유형을 미리 채우고, 건너뛰기 없이 push
            state.dateType = DateTypeFeature.State(
                indoorOutdoor: preference?.indoorOutdoor,
                activityLevel: preference?.activityLevel,
                dateTime: preference?.dateTime,
                dateFocus: preference?.dateFocus,
                showsSkip: false
            )
            return applyPath(state.path + [.dateType], state: &state)

        case let .connectionManageRequested(me, partner, daysTogether):
            state.connection = ConnectionManageFeature.State(
                me: me,
                partner: partner,
                daysTogether: daysTogether
            )
            return applyPath(state.path + [.connection], state: &state)

        case let .coupleConnectRequested(myNickname):
            state.couple = CoupleConnectFeature.State(myNickname: myNickname, showsSkip: false)
            return applyPath(state.path + [.connect], state: &state)

        case .logoutSucceeded:
            return .send(.delegate(.logoutSucceeded))

        case .accountWithdrawn:
            return .send(.delegate(.accountWithdrawn))

        case .sessionExpired:
            return .send(.delegate(.sessionExpired))

        case .noticeRequested:
            state.noticeList = NoticeListFeature.State()
            return applyPath(state.path + [.noticeList], state: &state)
        }
    }

    func handle(
        dateTypeDelegate: DateTypeFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch dateTypeDelegate {
        case let .saved(profile):
            // 저장 성공. 뒤로 돌아가고 새 유형을 마이페이지에 알린다
            var next = state.path
            if !next.isEmpty { next.removeLast() }
            return .concatenate(
                applyPath(next, state: &state),
                .send(.myPage(.datePreferenceUpdated(profile.datePreference)))
            )

        case .sessionExpired:
            return .concatenate(
                applyPath([], state: &state),
                .send(.delegate(.sessionExpired))
            )

        case .skipped:
            // 마이페이지엔 건너뛰기가 없어 오지 않는다
            return .none
        }
    }

    func handle(
        connectionDelegate: ConnectionManageFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch connectionDelegate {
        case .disconnected:
            // 연결 해제 성공 → 마이페이지로 돌아간다
            var next = state.path
            if !next.isEmpty { next.removeLast() }
            return applyPath(next, state: &state)

        case .sessionExpired:
            return .concatenate(
                applyPath([], state: &state),
                .send(.delegate(.sessionExpired))
            )
        }
    }

    func handle(
        noticeListDelegate: NoticeListFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch noticeListDelegate {
        case .back:
            var next = state.path
            if !next.isEmpty { next.removeLast() }
            return applyPath(next, state: &state)

        case let .noticeSelected(notice):
            // 상세 조회가 없어 목록에서 받은 값을 그대로 넘긴다
            state.noticeDetail = NoticeDetailFeature.State(notice: notice)
            return applyPath(state.path + [.noticeDetail], state: &state)
        }
    }

    func handle(
        noticeDetailDelegate: NoticeDetailFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch noticeDetailDelegate {
        case .back:
            var next = state.path
            if !next.isEmpty { next.removeLast() }
            return applyPath(next, state: &state)
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

        case .connected:
            // 연결 성공 → 커플 플로우를 닫고 연결 관리 화면으로 대체
            state.connection = ConnectionManageFeature.State()
            return applyPath([.connection], state: &state)

        case .skipped:
            // 마이페이지엔 건너뛰기가 없어 오지 않지만 방어적으로 닫는다
            var next = state.path
            next.removeAll(where: \.isCouple)
            return applyPath(next, state: &state)

        case .sessionExpired:
            return .concatenate(
                applyPath([], state: &state),
                .send(.delegate(.sessionExpired))
            )
        }
    }
}
