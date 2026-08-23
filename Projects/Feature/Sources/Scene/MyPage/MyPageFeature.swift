import Domain
import Foundation
import ThirdParty

@Reducer
public struct MyPageFeature {
    public enum Route: Hashable {
        case dateType
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
        // 나의 데이트 유형 push 스택
        public var path: [Route]
        public var dateType: DateTypeFeature.State?
        // 회원탈퇴 확인 모달
        public var isWithdrawModalPresented: Bool
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
            isWithdrawModalPresented: Bool = false,
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
            self.isWithdrawModalPresented = isWithdrawModalPresented
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
        case logoutButtonTapped
        case logoutResponse(Result<EquatableVoid, AuthError>)
        case profileEdit(PresentationAction<ProfileEditFeature.Action>)
        case pathChanged([Route])
        case dateType(DateTypeFeature.Action)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case logoutSucceeded
            case sessionExpired
        }
    }

    public struct EquatableVoid: Equatable, Sendable {
        public init() {}
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.profileClient) var profileClient

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

        case .withdrawTapped, .withdrawConfirmed, .dismissWithdrawModal:
            return handleWithdraw(state: &state, action: action)

        case .binding, .connectionTapped, .delegate:
            // 이동할 화면들은 아직 없음. 붙는 대로 연결
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
            if !path.contains(.dateType) { state.dateType = nil }
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
            // 실제 탈퇴 API 는 이후 연결. 지금은 모달만 닫는다
            state.isWithdrawModalPresented = false
            return .none

        case .dismissWithdrawModal:
            state.isWithdrawModalPresented = false
            return .none

        default:
            return .none
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
