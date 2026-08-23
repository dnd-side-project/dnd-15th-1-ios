import Domain
import Foundation
import SharedDesignSystem
import ThirdParty

@Reducer
public struct MyPageFeature {
    public enum Route: Hashable {
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
        public var nickname: String
        public var iconID: Int
        // 현재 데이트 유형. 나의 데이트 유형 화면에 미리 선택된 채로 넘긴다
        public var datePreference: DatePreference?
        // 알림 토글. 진입 시 서버 값으로 로드되고, 바꾸면 즉시 서버에 반영
        public var savedContentAlarmOn: Bool
        public var dateScheduleAlarmOn: Bool
        public var marketingAlarmOn: Bool
        // 마케팅 약관 버전. 마케팅을 켤 때 함께 보낸다
        public var marketingConsentVersion: String?
        public var availableMarketingConsentVersion: String?
        // 시트로 여는 약관 웹뷰 대상
        public var presentedTerms: TermsType?
        // 프로필 수정 바텀시트
        @Presents public var profileEdit: ProfileEditFeature.State?
        // push 스택. 나의 데이트 유형 / 연결 관리
        public var path: [Route]
        public var dateType: DateTypeFeature.State?
        public var connection: ConnectionManageFeature.State?
        public var couple: CoupleConnectFeature.State?
        // 회원탈퇴 확인 모달
        public var isWithdrawModalPresented: Bool
        public var isWithdrawing: Bool
        public var toast: ToastState?
        public var isLoading: Bool
        public var errorMessage: String?

        public init(
            nickname: String = "",
            iconID: Int = 1,
            datePreference: DatePreference? = nil,
            savedContentAlarmOn: Bool = false,
            dateScheduleAlarmOn: Bool = false,
            marketingAlarmOn: Bool = false,
            marketingConsentVersion: String? = nil,
            availableMarketingConsentVersion: String? = nil,
            presentedTerms: TermsType? = nil,
            profileEdit: ProfileEditFeature.State? = nil,
            path: [Route] = [],
            dateType: DateTypeFeature.State? = nil,
            connection: ConnectionManageFeature.State? = nil,
            couple: CoupleConnectFeature.State? = nil,
            isWithdrawModalPresented: Bool = false,
            isWithdrawing: Bool = false,
            toast: ToastState? = nil,
            isLoading: Bool = false,
            errorMessage: String? = nil
        ) {
            self.nickname = nickname
            self.iconID = iconID
            self.datePreference = datePreference
            self.savedContentAlarmOn = savedContentAlarmOn
            self.dateScheduleAlarmOn = dateScheduleAlarmOn
            self.marketingAlarmOn = marketingAlarmOn
            self.marketingConsentVersion = marketingConsentVersion
            self.availableMarketingConsentVersion = availableMarketingConsentVersion
            self.presentedTerms = presentedTerms
            self.profileEdit = profileEdit
            self.path = path
            self.dateType = dateType
            self.connection = connection
            self.couple = couple
            self.isWithdrawModalPresented = isWithdrawModalPresented
            self.isWithdrawing = isWithdrawing
            self.toast = toast
            self.isLoading = isLoading
            self.errorMessage = errorMessage
        }
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case profileLoaded(UserProfile)
        case notificationSettingsLoaded(NotificationSettings)
        case notificationSettingsUpdateFailed
        case profileEditTapped
        case dateTypeTapped
        case connectionTapped
        case termsLinkTapped(TermsType)
        case dismissTerms
        case withdrawTapped
        case withdrawConfirmed
        case dismissWithdrawModal
        case withdrawSucceeded
        case withdrawFailed(ProfileError)
        case dismissToast
        case logoutButtonTapped
        case logoutResponse(Result<EquatableVoid, AuthError>)
        case profileEdit(PresentationAction<ProfileEditFeature.Action>)
        case pathChanged([Route])
        case dateType(DateTypeFeature.Action)
        case connection(ConnectionManageFeature.Action)
        case connectionStatusResolved(CoupleStatus?)
        case connectionStatusFailed(CoupleError)
        case couple(CoupleConnectFeature.Action)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case logoutSucceeded
            case accountWithdrawn
            case sessionExpired
        }
    }

    public struct EquatableVoid: Equatable, Sendable {
        public init() {}
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.profileClient) var profileClient
    @Dependency(\.coupleClient) var coupleClient

    private enum CancelID { case updateNotification }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce(core)
            .ifLet(\.$profileEdit, action: \.profileEdit) {
                ProfileEditFeature()
            }
            .ifLet(\.dateType, action: \.dateType) {
                DateTypeFeature()
            }
            .ifLet(\.connection, action: \.connection) {
                ConnectionManageFeature()
            }
            .ifLet(\.couple, action: \.couple) {
                CoupleConnectFeature()
            }
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .merge(loadProfile(), loadNotificationSettings())

        case let .profileLoaded(profile):
            state.nickname = profile.nickname
            state.iconID = profile.iconID
            state.datePreference = profile.datePreference
            return .none

        case let .notificationSettingsLoaded(settings):
            state.savedContentAlarmOn = settings.contentSavedEnabled
            state.dateScheduleAlarmOn = settings.dateScheduleEnabled
            state.marketingAlarmOn = settings.marketingEnabled
            state.marketingConsentVersion = settings.marketingConsentVersion
            state.availableMarketingConsentVersion = settings.availableMarketingConsentVersion
            return .none

        case .notificationSettingsUpdateFailed:
            // 저장 실패면 서버 값으로 되돌려 화면과 서버를 다시 맞춘다
            return loadNotificationSettings()

        case .binding(\.savedContentAlarmOn), .binding(\.dateScheduleAlarmOn),
             .binding(\.marketingAlarmOn):
            return updateNotificationSettings(state: state)

        case .logoutButtonTapped, .logoutResponse:
            return handleLogout(state: &state, action: action)

        case .termsLinkTapped, .dismissTerms:
            return handleTerms(state: &state, action: action)

        case .profileEditTapped, .profileEdit:
            return handleProfileEdit(state: &state, action: action)

        case .dateTypeTapped, .pathChanged, .dateType:
            return handleDateType(state: &state, action: action)

        case .connectionTapped, .connectionStatusResolved, .connectionStatusFailed,
             .connection, .couple:
            return handleConnection(state: &state, action: action)

        case .withdrawTapped, .withdrawConfirmed, .dismissWithdrawModal,
             .withdrawSucceeded, .withdrawFailed, .dismissToast:
            return handleWithdraw(state: &state, action: action)

        case .binding, .delegate:
            return .none
        }
    }

    private func handleProfileEdit(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .profileEditTapped:
            state.profileEdit = ProfileEditFeature.State(
                nickname: state.nickname,
                selectedIconID: state.iconID
            )
            return .none

        case let .profileEdit(.presented(.delegate(.saved(nickname, iconID)))):
            // API 는 이후. 지금은 화면 값만 갱신하고 닫는다
            state.nickname = nickname
            state.iconID = iconID
            state.profileEdit = nil
            return .none

        case .profileEdit(.presented(.delegate(.dismiss))):
            state.profileEdit = nil
            return .none

        case .profileEdit(.presented(.delegate(.sessionExpired))):
            // 시트를 닫고 세션 만료를 위로 올려 로그인으로 보낸다
            state.profileEdit = nil
            return .send(.delegate(.sessionExpired))

        case .profileEdit:
            return .none

        default:
            return .none
        }
    }

    private func handleDateType(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .dateTypeTapped:
            // 현재 데이트 유형을 미리 채우고, 건너뛰기 없이 push
            let pref = state.datePreference
            state.dateType = DateTypeFeature.State(
                indoorOutdoor: pref?.indoorOutdoor,
                activityLevel: pref?.activityLevel,
                dateTime: pref?.dateTime,
                dateFocus: pref?.dateFocus,
                showsSkip: false
            )
            state.path.append(.dateType)
            return .none

        case let .pathChanged(path):
            state.path = path
            // 스택에서 빠진 화면의 자식 상태를 내린다
            if !path.contains(.dateType) { state.dateType = nil }
            if !path.contains(.connection) { state.connection = nil }
            if !path.contains(where: \.isCouple) { state.couple = nil }
            return .none

        case let .dateType(.delegate(.saved(profile))):
            // 저장 성공. 새 유형을 반영하고 뒤로 돌아온다
            state.datePreference = profile.datePreference
            state.dateType = nil
            if !state.path.isEmpty { state.path.removeLast() }
            return .none

        case .dateType(.delegate(.sessionExpired)):
            state.dateType = nil
            state.path = []
            return .send(.delegate(.sessionExpired))

        case .dateType:
            // 마이페이지엔 건너뛰기가 없어 skipped 는 오지 않는다
            return .none

        default:
            return .none
        }
    }
}

private extension MyPageFeature {
    func handleConnection(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .connectionTapped:
            // 연결 여부를 먼저 확인해 관리 화면·연결 플로우를 가른다
            return .run { [coupleClient] send in
                do {
                    let status = try await coupleClient.current()
                    await send(.connectionStatusResolved(status))
                } catch {
                    await send(.connectionStatusFailed(error as? CoupleError ?? .unknown))
                }
            }

        case let .connectionStatusResolved(status):
            // 성공 응답. nil 은 진짜 미연결(404)이라 연결 플로우로 보낸다
            if status?.connected == true {
                state.connection = ConnectionManageFeature.State(
                    me: status?.me,
                    partner: status?.partner,
                    daysTogether: status?.daysTogether
                )
                state.path.append(.connection)
            } else {
                state.couple = CoupleConnectFeature.State(myNickname: state.nickname, showsSkip: false)
                state.path.append(.connect)
            }
            return .none

        case let .connectionStatusFailed(error):
            // 조회 실패를 미연결로 오해하지 않도록 이동 없이 알린다
            if error == .unauthorized {
                return .send(.delegate(.sessionExpired))
            }
            state.toast = Self.connectionStatusToast(for: error)
            return .none

        case let .couple(.delegate(delegate)):
            return handleCoupleDelegate(state: &state, delegate: delegate)

        case .connection(.delegate(.disconnected)):
            // 연결 해제 성공 → 마이페이지로 돌아간다
            state.connection = nil
            if !state.path.isEmpty { state.path.removeLast() }
            return .none

        case .connection(.delegate(.sessionExpired)):
            state.connection = nil
            state.path = []
            return .send(.delegate(.sessionExpired))

        case .connection, .couple:
            return .none

        default:
            return .none
        }
    }

    func handleCoupleDelegate(
        state: inout State,
        delegate: CoupleConnectFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case .showCodeInput:
            state.path.append(.codeInput)
            return .none

        case .showComplete:
            state.path.append(.complete)
            return .none

        case .back:
            guard !state.path.isEmpty else { return .none }
            state.path.removeLast()
            if !state.path.contains(where: \.isCouple) { state.couple = nil }
            return .none

        case .connected:
            // 연결 성공 → 커플 플로우를 닫고 연결 관리 화면으로 대체
            state.couple = nil
            state.connection = ConnectionManageFeature.State()
            state.path = [.connection]
            return .none

        case .skipped:
            // 마이페이지엔 건너뛰기가 없어 오지 않지만 방어적으로 닫는다
            state.couple = nil
            state.path.removeAll(where: \.isCouple)
            return .none

        case .sessionExpired:
            state.couple = nil
            state.path = []
            return .send(.delegate(.sessionExpired))
        }
    }

    func handleTerms(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .termsLinkTapped(terms):
            // 약관 웹뷰를 시트로 연다. 지원 URL 이 아니면 무시(로그인과 동일)
            guard let url = terms.url, SupportedWebURL.isSupported(url) else { return .none }
            state.presentedTerms = terms
            return .none

        case .dismissTerms:
            state.presentedTerms = nil
            return .none

        default:
            return .none
        }
    }

    func handleWithdraw(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .withdrawTapped:
            state.isWithdrawModalPresented = true
            return .none

        case .withdrawConfirmed:
            guard !state.isWithdrawing else { return .none }
            state.isWithdrawing = true
            return withdraw()

        case .withdrawSucceeded:
            // 탈퇴 성공. 세션은 이미 정리됐고 탈퇴 안내와 함께 로그인으로 보낸다
            state.isWithdrawing = false
            state.isWithdrawModalPresented = false
            return .send(.delegate(.accountWithdrawn))

        case let .withdrawFailed(error):
            state.isWithdrawing = false
            state.isWithdrawModalPresented = false
            // 인증 만료는 로그인으로, 나머지는 토스트
            if error == .unauthorized {
                return .send(.delegate(.sessionExpired))
            }
            state.toast = Self.withdrawToast(for: error)
            return .none

        case .dismissWithdrawModal:
            state.isWithdrawModalPresented = false
            return .none

        case .dismissToast:
            state.toast = nil
            return .none

        default:
            return .none
        }
    }

    // 탈퇴 후 로컬 세션까지 정리. 서버 로그아웃 실패는 무시
    func withdraw() -> Effect<Action> {
        .run { [profileClient, authClient] send in
            do {
                try await profileClient.withdraw()
                try? await authClient.logout()
                await send(.withdrawSucceeded)
            } catch {
                await send(.withdrawFailed(error as? ProfileError ?? .unknown))
            }
        }
    }

    static func withdrawToast(for error: ProfileError) -> ToastState {
        switch error {
        case .network:
            .error("네트워크 연결을 확인해 주세요.")
        case .invalidNickname, .unauthorized, .unknown:
            .error("탈퇴에 실패했어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    static func connectionStatusToast(for error: CoupleError) -> ToastState {
        switch error {
        case .network:
            .error("네트워크 연결을 확인해 주세요.")
        default:
            .error("연결 상태를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    func handleLogout(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .logoutButtonTapped:
            guard !state.isLoading else { return .none }
            state.isLoading = true
            state.errorMessage = nil
            return logout()

        case .logoutResponse(.success):
            state.isLoading = false
            return .send(.delegate(.logoutSucceeded))

        case let .logoutResponse(.failure(error)):
            state.isLoading = false
            state.errorMessage = "로그아웃에 실패했습니다."
            if error == .unauthorized {
                return .send(.delegate(.sessionExpired))
            }
            return .none

        default:
            return .none
        }
    }

    private func loadProfile() -> Effect<Action> {
        .run { [profileClient] send in
            guard let profile = try? await profileClient.member() else { return }
            await send(.profileLoaded(profile))
        }
    }

    private func loadNotificationSettings() -> Effect<Action> {
        .run { [profileClient] send in
            guard let settings = try? await profileClient.notificationSettings() else { return }
            await send(.notificationSettingsLoaded(settings))
        }
    }

    // 현재 토글 상태를 통째로 PUT. 마케팅 동의 버전은 저장값이 없으면 최신 가능 버전으로 보낸다
    private func updateNotificationSettings(state: State) -> Effect<Action> {
        let outgoing = NotificationSettings(
            contentSavedEnabled: state.savedContentAlarmOn,
            dateScheduleEnabled: state.dateScheduleAlarmOn,
            marketingEnabled: state.marketingAlarmOn,
            marketingConsentVersion: state.marketingConsentVersion
                ?? state.availableMarketingConsentVersion,
            availableMarketingConsentVersion: state.availableMarketingConsentVersion
        )
        return .run { [profileClient] send in
            do {
                let updated = try await profileClient.updateNotificationSettings(outgoing)
                await send(.notificationSettingsLoaded(updated))
            } catch {
                // 다음 토글이 이 PUT 을 취소한 경우는 실패가 아니다
                if error is CancellationError { return }
                await send(.notificationSettingsUpdateFailed)
            }
        }
        .cancellable(id: CancelID.updateNotification, cancelInFlight: true)
    }

    private func logout() -> Effect<Action> {
        .run { [authClient] send in
            do {
                try await authClient.logout()
                await send(.logoutResponse(.success(EquatableVoid())))
            } catch {
                await send(.logoutResponse(.failure(mapAuthError(error))))
            }
        }
    }
}

private func mapAuthError(_ error: Error) -> AuthError {
    error as? AuthError ?? .unknown
}
