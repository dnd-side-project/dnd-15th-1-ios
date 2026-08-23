import Domain
import Foundation
import SharedDesignSystem
import ThirdParty

@Reducer
public struct ConnectionManageFeature {
    @ObservableState
    public struct State: Equatable {
        public var me: CoupleMember?
        public var partner: CoupleMember?
        public var daysTogether: Int?
        public var isDisconnectModalPresented: Bool
        public var isDisconnecting: Bool
        public var toast: ToastState?

        public init(
            me: CoupleMember? = nil,
            partner: CoupleMember? = nil,
            daysTogether: Int? = nil,
            isDisconnectModalPresented: Bool = false,
            isDisconnecting: Bool = false,
            toast: ToastState? = nil
        ) {
            self.me = me
            self.partner = partner
            self.daysTogether = daysTogether
            self.isDisconnectModalPresented = isDisconnectModalPresented
            self.isDisconnecting = isDisconnecting
            self.toast = toast
        }
    }

    public enum Action: Equatable {
        case onAppear
        case coupleLoaded(CoupleStatus)
        case disconnectTapped
        case disconnectConfirmed
        case dismissDisconnectModal
        case disconnectSucceeded
        case disconnectFailed(CoupleError)
        case dismissToast
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 연결 해제 성공. 상위가 뒤로 보낸다
            case disconnected
            case sessionExpired
        }
    }

    @Dependency(\.coupleClient) var coupleClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .run { [coupleClient] send in
                guard let status = try? await coupleClient.current() else { return }
                await send(.coupleLoaded(status))
            }

        case let .coupleLoaded(status):
            state.me = status.me
            state.partner = status.partner
            state.daysTogether = status.daysTogether
            return .none

        case .disconnectTapped:
            state.isDisconnectModalPresented = true
            return .none

        case .disconnectConfirmed:
            guard !state.isDisconnecting else { return .none }
            state.isDisconnecting = true
            return disconnect()

        case .disconnectSucceeded:
            state.isDisconnecting = false
            state.isDisconnectModalPresented = false
            return .send(.delegate(.disconnected))

        case let .disconnectFailed(error):
            state.isDisconnecting = false
            state.isDisconnectModalPresented = false
            if error == .unauthorized {
                return .send(.delegate(.sessionExpired))
            }
            state.toast = Self.toast(for: error)
            return .none

        case .dismissDisconnectModal:
            state.isDisconnectModalPresented = false
            return .none

        case .dismissToast:
            state.toast = nil
            return .none

        case .delegate:
            return .none
        }
    }

    private func disconnect() -> Effect<Action> {
        .run { [coupleClient] send in
            do {
                try await coupleClient.disconnect()
                await send(.disconnectSucceeded)
            } catch {
                await send(.disconnectFailed(error as? CoupleError ?? .unknown))
            }
        }
    }

    private static func toast(for error: CoupleError) -> ToastState {
        switch error {
        case .network:
            .error("네트워크 연결을 확인해 주세요.")
        case .rateLimited:
            .error("요청이 많아요. 잠시 후 다시 시도해 주세요.")
        default:
            .error("연결 해제에 실패했어요. 잠시 후 다시 시도해 주세요.")
        }
    }
}
