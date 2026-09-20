import Domain
import Foundation
import SharedDesignSystem
import ThirdParty

@Reducer
public struct MyPageFeature {
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
        // 최초 데이터 로드 중. 이때 마이페이지 전체를 스켈레톤으로 보인다
        public var isSkeleton: Bool
        // 시트로 여는 약관 웹뷰 대상
        public var presentedTerms: TermsType?
        // 프로필 수정 바텀시트. 플래그가 먼저 내려가고, 퇴장이 끝난 뒤 profileEdit 을 비운다
        @Presents public var profileEdit: ProfileEditFeature.State?
        public var isProfileEditPresented: Bool
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
            isSkeleton: Bool = true,
            presentedTerms: TermsType? = nil,
            profileEdit: ProfileEditFeature.State? = nil,
            isProfileEditPresented: Bool = false,
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
            self.isSkeleton = isSkeleton
            self.presentedTerms = presentedTerms
            self.profileEdit = profileEdit
            self.isProfileEditPresented = isProfileEditPresented
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
        case notificationSettingsLoadFailed
        case notificationSettingsUpdateFailed
        case profileEditTapped
        case profileEditCloseRequested
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
        case connectionStatusResolved(CoupleStatus)
        case connectionStatusFailed(CoupleError)
        // 전환 담당이 데이트 유형 저장 결과를 내려보낸다
        case datePreferenceUpdated(DatePreference?)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case logoutSucceeded
            case accountWithdrawn
            case sessionExpired
            /// 나의 데이트 유형으로 간다. 지금 값을 함께 올려 미리 채우게 한다
            case dateTypeRequested(DatePreference?)
            /// 연결됨. 연결 관리 화면의 첫 값을 함께 올린다
            case connectionManageRequested(me: CoupleMember, partner: CoupleMember, daysTogether: Int?)
            /// 미연결. 커플 연결 3화면으로 간다
            case coupleConnectRequested(myNickname: String)
        }
    }

    public struct EquatableVoid: Equatable, Sendable {
        public init() {}
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.profileClient) var profileClient
    @Dependency(\.coupleClient) var coupleClient
    @Dependency(\.notificationClient) var notificationClient

    private enum CancelID { case updateNotification }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce(core)
            .ifLet(\.$profileEdit, action: \.profileEdit) {
                ProfileEditFeature()
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
            state.isSkeleton = false
            state.savedContentAlarmOn = settings.contentSavedEnabled
            state.dateScheduleAlarmOn = settings.dateScheduleEnabled
            state.marketingAlarmOn = settings.marketingEnabled
            state.marketingConsentVersion = settings.marketingConsentVersion
            state.availableMarketingConsentVersion = settings.availableMarketingConsentVersion
            return .none

        case .notificationSettingsLoadFailed, .notificationSettingsUpdateFailed:
            return handleNotificationFailure(state: &state, action: action)

        case .binding(\.savedContentAlarmOn), .binding(\.dateScheduleAlarmOn),
             .binding(\.marketingAlarmOn):
            return updateNotificationSettings(state: state)

        case .logoutButtonTapped, .logoutResponse:
            return handleLogout(state: &state, action: action)

        case .termsLinkTapped, .dismissTerms:
            return handleTerms(state: &state, action: action)

        case .profileEditTapped, .profileEditCloseRequested, .profileEdit:
            return handleProfileEdit(state: &state, action: action)

        case .dateTypeTapped, .datePreferenceUpdated:
            return handleDateType(state: &state, action: action)

        case .connectionTapped, .connectionStatusResolved, .connectionStatusFailed:
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
            state.isProfileEditPresented = true
            return .none

        case .profileEditCloseRequested:
            state.isProfileEditPresented = false
            return .none

        case let .profileEdit(.presented(.delegate(.saved(nickname, iconID)))):
            state.nickname = nickname
            state.iconID = iconID
            state.isProfileEditPresented = false
            return .none

        case .profileEdit(.presented(.delegate(.dismiss))):
            state.isProfileEditPresented = false
            return .none

        case .profileEdit(.presented(.delegate(.sessionExpired))):
            // 화면을 떠나므로 퇴장 애니메이션을 기다리지 않는다
            state.isProfileEditPresented = false
            state.profileEdit = nil
            return .send(.delegate(.sessionExpired))

        case .profileEdit(.dismiss):
            state.isProfileEditPresented = false
            return .none

        case .profileEdit:
            return .none

        default:
            return .none
        }
    }

    private func handleDateType(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .dateTypeTapped:
            // 지금 값을 실어 올린다. 화면 상태는 전환 담당이 만든다
            return .send(.delegate(.dateTypeRequested(state.datePreference)))

        case let .datePreferenceUpdated(preference):
            // 저장 결과가 전환 담당을 거쳐 내려온다. 서버에 다시 묻지 않는다
            state.datePreference = preference
            return .none

        default:
            return .none
        }
    }
}

private extension MyPageFeature {
    func handleNotificationFailure(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .notificationSettingsLoadFailed:
            // 최초 로드 실패면 스켈레톤을 걷고 기본 화면을 보인다
            state.isSkeleton = false
            return .none

        case .notificationSettingsUpdateFailed:
            // 저장 실패면 서버 값으로 되돌려 화면과 서버를 다시 맞춘다
            return loadNotificationSettings()

        default:
            return .none
        }
    }

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
            // 연결 안 됨(404 포함)이면 연결 플로우로 보낸다
            if case let .connected(me, partner, daysTogether) = status {
                return .send(.delegate(.connectionManageRequested(
                    me: me,
                    partner: partner,
                    daysTogether: daysTogether
                )))
            }
            return .send(.delegate(.coupleConnectRequested(myNickname: state.nickname)))

        case let .connectionStatusFailed(error):
            // 조회 실패를 미연결로 오해하지 않도록 이동 없이 알린다
            if error == .unauthorized {
                return .send(.delegate(.sessionExpired))
            }
            state.toast = Self.connectionStatusToast(for: error)
            return .none

        default:
            return .none
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
        .run { [notificationClient] send in
            do {
                let settings = try await notificationClient.notificationSettings()
                await send(.notificationSettingsLoaded(settings))
            } catch {
                // 실패해도 스켈레톤은 걷는다(무한 로딩 방지)
                await send(.notificationSettingsLoadFailed)
            }
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
        return .run { [notificationClient] send in
            do {
                let updated = try await notificationClient.updateNotificationSettings(outgoing)
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
