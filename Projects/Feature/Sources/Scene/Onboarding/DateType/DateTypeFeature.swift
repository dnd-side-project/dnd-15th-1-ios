import Domain
import Foundation
import SharedDesignSystem
import ThirdParty

@Reducer
public struct DateTypeFeature {
    @ObservableState
    public struct State: Equatable {
        public var indoorOutdoor: IndoorOutdoor?
        public var activityLevel: ActivityLevel?
        public var dateTime: DateTime?
        public var dateFocus: DateFocus?
        public var isSubmitting: Bool
        public var isTooltipPresented: Bool
        public var toast: ToastState?

        public init(
            indoorOutdoor: IndoorOutdoor? = nil,
            activityLevel: ActivityLevel? = nil,
            dateTime: DateTime? = nil,
            dateFocus: DateFocus? = nil,
            isSubmitting: Bool = false,
            isTooltipPresented: Bool = false,
            toast: ToastState? = nil
        ) {
            self.indoorOutdoor = indoorOutdoor
            self.activityLevel = activityLevel
            self.dateTime = dateTime
            self.dateFocus = dateFocus
            self.isSubmitting = isSubmitting
            self.isTooltipPresented = isTooltipPresented
            self.toast = toast
        }

        /// 4축이 전부 채워졌을 때만 만들어진다. 부분 선택은 저장 대상이 아니다
        public var datePreference: DatePreference? {
            guard
                let indoorOutdoor,
                let activityLevel,
                let dateTime,
                let dateFocus
            else {
                return nil
            }
            return DatePreference(
                indoorOutdoor: indoorOutdoor,
                activityLevel: activityLevel,
                dateTime: dateTime,
                dateFocus: dateFocus
            )
        }

        public var isSaveEnabled: Bool {
            datePreference != nil && !isSubmitting
        }
    }

    public enum Action: Equatable {
        case indoorOutdoorSelected(IndoorOutdoor)
        case activityLevelSelected(ActivityLevel)
        case dateTimeSelected(DateTime)
        case dateFocusSelected(DateFocus)
        case tooltipButtonTapped
        case tooltipDismissed
        case saveButtonTapped
        case skipButtonTapped
        case updateDatePreferenceResponse(Result<UserProfile, ProfileError>)
        case dismissToast
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case saved(UserProfile)
            case skipped
            case sessionExpired
        }
    }

    @Dependency(\.profileClient) var profileClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .indoorOutdoorSelected(value): return indoorOutdoorSelected(value, state: &state)
            case let .activityLevelSelected(value): return activityLevelSelected(value, state: &state)
            case let .dateTimeSelected(value): return dateTimeSelected(value, state: &state)
            case let .dateFocusSelected(value): return dateFocusSelected(value, state: &state)
            case .tooltipButtonTapped: return tooltipButtonTapped(state: &state)
            case .tooltipDismissed: return tooltipDismissed(state: &state)
            case .saveButtonTapped: return saveButtonTapped(state: &state)
            case .skipButtonTapped: return skipButtonTapped(state: &state)
            case let .updateDatePreferenceResponse(result): return updateDatePreferenceResponse(result, state: &state)
            case .dismissToast: return dismissToast(state: &state)
            case .delegate: return .none
            }
        }
    }
}

private extension DateTypeFeature {
    /// 저장 요청은 누른 시점의 4축을 실어 보낸다. 응답을 기다리는 동안 선택이 바뀌면
    /// 서버 값과 화면이 어긋나므로, 저장 중에는 선택과 건너뛰기를 받지 않는다
    func indoorOutdoorSelected(
        _ value: IndoorOutdoor,
        state: inout State
    ) -> Effect<Action> {
        guard !state.isSubmitting else { return .none }
        state.indoorOutdoor = value
        state.isTooltipPresented = false
        return .none
    }

    func activityLevelSelected(
        _ value: ActivityLevel,
        state: inout State
    ) -> Effect<Action> {
        guard !state.isSubmitting else { return .none }
        state.activityLevel = value
        state.isTooltipPresented = false
        return .none
    }

    func dateTimeSelected(
        _ value: DateTime,
        state: inout State
    ) -> Effect<Action> {
        guard !state.isSubmitting else { return .none }
        state.dateTime = value
        state.isTooltipPresented = false
        return .none
    }

    func dateFocusSelected(
        _ value: DateFocus,
        state: inout State
    ) -> Effect<Action> {
        guard !state.isSubmitting else { return .none }
        state.dateFocus = value
        state.isTooltipPresented = false
        return .none
    }

    func skipButtonTapped(state: inout State) -> Effect<Action> {
        guard !state.isSubmitting else { return .none }
        state.isTooltipPresented = false
        return .send(.delegate(.skipped))
    }

    func tooltipButtonTapped(state: inout State) -> Effect<Action> {
        state.isTooltipPresented.toggle()
        return .none
    }

    func tooltipDismissed(state: inout State) -> Effect<Action> {
        state.isTooltipPresented = false
        return .none
    }

    func dismissToast(state: inout State) -> Effect<Action> {
        state.toast = nil
        return .none
    }

    func saveButtonTapped(state: inout State) -> Effect<Action> {
        guard state.isSaveEnabled, let preference = state.datePreference else { return .none }
        state.isSubmitting = true
        state.isTooltipPresented = false
        state.toast = nil
        return .run { [profileClient] send in
            do {
                let profile = try await profileClient.updateDatePreference(preference)
                await send(.updateDatePreferenceResponse(.success(profile)))
            } catch {
                await send(.updateDatePreferenceResponse(.failure(mapProfileError(error))))
            }
        }
    }

    func updateDatePreferenceResponse(
        _ result: Result<UserProfile, ProfileError>,
        state: inout State
    ) -> Effect<Action> {
        state.isSubmitting = false
        switch result {
        case let .success(profile):
            return .send(.delegate(.saved(profile)))
        case let .failure(error):
            return handleUpdateFailure(error, state: &state)
        }
    }

    func handleUpdateFailure(
        _ error: ProfileError,
        state: inout State
    ) -> Effect<Action> {
        switch error {
        case .network:
            state.toast = .error("네트워크 연결을 확인해 주세요.")
            return .none
        case .unauthorized:
            return .send(.delegate(.sessionExpired))
        case .invalidNickname, .unknown:
            state.toast = .error("잠시 후 다시 시도해 주세요.")
            return .none
        }
    }
}

private func mapProfileError(_ error: Error) -> ProfileError {
    error as? ProfileError ?? .unknown
}
