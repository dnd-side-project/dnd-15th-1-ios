import Domain
import Foundation
import ThirdParty

@Reducer
public struct MyPageFeature {
    @ObservableState
    public struct State: Equatable {
        public var nickname: String
        public var iconID: Int
        // 알림 토글. 서버 연동 전까지 화면 상태만 유지
        public var savedContentAlarmOn: Bool
        public var dateScheduleAlarmOn: Bool
        public var marketingAlarmOn: Bool
        public var isLoading: Bool
        public var errorMessage: String?

        public init(
            nickname: String = "",
            iconID: Int = 1,
            savedContentAlarmOn: Bool = true,
            dateScheduleAlarmOn: Bool = true,
            marketingAlarmOn: Bool = false,
            isLoading: Bool = false,
            errorMessage: String? = nil
        ) {
            self.nickname = nickname
            self.iconID = iconID
            self.savedContentAlarmOn = savedContentAlarmOn
            self.dateScheduleAlarmOn = dateScheduleAlarmOn
            self.marketingAlarmOn = marketingAlarmOn
            self.isLoading = isLoading
            self.errorMessage = errorMessage
        }
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case profileLoaded(UserProfile)
        case notificationSettingsLoaded(NotificationSettings)
        case profileEditTapped
        case dateTypeTapped
        case connectionTapped
        case feedbackTapped
        case termsLinkTapped(TermsType)
        case withdrawTapped
        case logoutButtonTapped
        case logoutResponse(Result<EquatableVoid, AuthError>)
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

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .merge(loadProfile(), loadNotificationSettings())

        case let .profileLoaded(profile):
            state.nickname = profile.nickname
            state.iconID = profile.iconID
            return .none

        case let .notificationSettingsLoaded(settings):
            state.savedContentAlarmOn = settings.contentSavedEnabled
            state.dateScheduleAlarmOn = settings.dateScheduleEnabled
            state.marketingAlarmOn = settings.marketingEnabled
            return .none

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

        case .binding, .profileEditTapped, .dateTypeTapped, .connectionTapped,
             .feedbackTapped, .termsLinkTapped, .withdrawTapped, .delegate:
            // 이동할 화면들은 아직 없음. 붙는 대로 연결
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
