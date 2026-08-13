import Domain
import Foundation
import SharedDesignSystem
import ThirdParty

@Reducer
public struct CoupleConnectFeature {
    /// 초대 코드 자릿수. 다 차야 CTA 가 열리고 자동 제출은 없다
    static let codeLength = 5

    /// 루트 아래로 push 되는 화면. 리듀서는 하나고 이 값 배열이 네비게이션 경로다
    public enum Screen: Hashable {
        case codeInput
        case complete
    }

    @ObservableState
    public struct State: Equatable {
        public var myNickname: String
        public var path: [Screen]
        public var inviteCode: InviteCode?
        public var isLoadingInviteCode: Bool
        public var hasAttemptedInviteCode: Bool
        public var inviteCodeError: String?
        public var isSkipConfirmPresented: Bool
        public var code: String
        public var isConnecting: Bool
        public var connectedCouple: Couple?
        public var toast: ToastState?

        public init(
            myNickname: String,
            path: [Screen] = [],
            inviteCode: InviteCode? = nil,
            isLoadingInviteCode: Bool = false,
            hasAttemptedInviteCode: Bool = false,
            inviteCodeError: String? = nil,
            isSkipConfirmPresented: Bool = false,
            code: String = "",
            isConnecting: Bool = false,
            connectedCouple: Couple? = nil,
            toast: ToastState? = nil
        ) {
            self.myNickname = myNickname
            self.path = path
            self.inviteCode = inviteCode
            self.isLoadingInviteCode = isLoadingInviteCode
            self.hasAttemptedInviteCode = hasAttemptedInviteCode
            self.inviteCodeError = inviteCodeError
            self.isSkipConfirmPresented = isSkipConfirmPresented
            self.code = code
            self.isConnecting = isConnecting
            self.connectedCouple = connectedCouple
            self.toast = toast
        }

        public var isConnectEnabled: Bool {
            code.count == CoupleConnectFeature.codeLength && !isConnecting && toast == nil
        }

        public var partnerNickname: String {
            connectedCouple?.partnerNickname ?? ""
        }
    }

    public enum Action: Equatable {
        case onAppear
        case inviteCodeResponse(Result<InviteCode, CoupleError>)
        case retryInviteCodeButtonTapped
        case skipButtonTapped
        case skipConfirmed
        case skipConfirmDismissed
        case codeInputButtonTapped
        case codeChanged(String)
        case connectButtonTapped
        case connectResponse(Result<Couple, CoupleError>)
        case completeButtonTapped
        case backButtonTapped
        case pathChanged([Screen])
        case dismissToast
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case connected(Couple)
            case skipped
            case sessionExpired
        }
    }

    @Dependency(\.coupleClient) var coupleClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear: return onAppear(state: &state)
            case let .inviteCodeResponse(result): return inviteCodeResponse(result, state: &state)
            case .retryInviteCodeButtonTapped: return retryInviteCodeButtonTapped(state: &state)
            case .skipButtonTapped: return skipButtonTapped(state: &state)
            case .skipConfirmed: return skipConfirmed(state: &state)
            case .skipConfirmDismissed: return skipConfirmDismissed(state: &state)
            case .codeInputButtonTapped: return codeInputButtonTapped(state: &state)
            case let .codeChanged(code): return codeChanged(code, state: &state)
            case .connectButtonTapped: return connectButtonTapped(state: &state)
            case let .connectResponse(result): return connectResponse(result, state: &state)
            case .completeButtonTapped: return completeButtonTapped(state: &state)
            case .backButtonTapped: return backButtonTapped(state: &state)
            case let .pathChanged(path): return pathChanged(path, state: &state)
            case .dismissToast: return dismissToast(state: &state)
            case .delegate: return .none
            }
        }
    }
}

private extension CoupleConnectFeature {
    func onAppear(state: inout State) -> Effect<Action> {
        guard state.inviteCode == nil, !state.isLoadingInviteCode else { return .none }
        return loadInviteCode(state: &state)
    }

    func retryInviteCodeButtonTapped(state: inout State) -> Effect<Action> {
        guard !state.isLoadingInviteCode else { return .none }
        return loadInviteCode(state: &state)
    }

    func skipButtonTapped(state: inout State) -> Effect<Action> {
        state.isSkipConfirmPresented = true
        return .none
    }

    func skipConfirmed(state: inout State) -> Effect<Action> {
        state.isSkipConfirmPresented = false
        return .send(.delegate(.skipped))
    }

    func skipConfirmDismissed(state: inout State) -> Effect<Action> {
        state.isSkipConfirmPresented = false
        return .none
    }

    func codeInputButtonTapped(state: inout State) -> Effect<Action> {
        state.path.append(.codeInput)
        return .none
    }

    func completeButtonTapped(state: inout State) -> Effect<Action> {
        guard let couple = state.connectedCouple else { return .none }
        return .send(.delegate(.connected(couple)))
    }

    func backButtonTapped(state: inout State) -> Effect<Action> {
        guard !state.path.isEmpty else { return .none }
        let path = Array(state.path.dropLast())
        return pathChanged(path, state: &state)
    }

    func pathChanged(
        _ path: [Screen],
        state: inout State
    ) -> Effect<Action> {
        state.path = path
        // 이전 화면에서 띄운 알림은 경로가 바뀌면 더 이상 유효하지 않다
        state.toast = nil
        return .none
    }

    func dismissToast(state: inout State) -> Effect<Action> {
        state.toast = nil
        return .none
    }

    func loadInviteCode(state: inout State) -> Effect<Action> {
        state.isLoadingInviteCode = true
        state.hasAttemptedInviteCode = true
        state.inviteCodeError = nil
        return .run { [coupleClient] send in
            do {
                let inviteCode = try await coupleClient.inviteCode()
                await send(.inviteCodeResponse(.success(inviteCode)))
            } catch {
                await send(.inviteCodeResponse(.failure(mapCoupleError(error))))
            }
        }
    }

    func inviteCodeResponse(
        _ result: Result<InviteCode, CoupleError>,
        state: inout State
    ) -> Effect<Action> {
        state.isLoadingInviteCode = false
        switch result {
        case let .success(inviteCode):
            state.inviteCode = inviteCode
            state.inviteCodeError = nil
            return .none
        case let .failure(error):
            guard error != .unauthorized else {
                return .send(.delegate(.sessionExpired))
            }
            state.inviteCodeError = error == .network
                ? "네트워크 연결을 확인해 주세요"
                : "잠시 후 다시 시도해 주세요"
            return .none
        }
    }

    func codeChanged(
        _ code: String,
        state: inout State
    ) -> Effect<Action> {
        // 코드를 고치면 실패 메시지도 같이 사라진다
        state.toast = nil
        state.code = normalizedCode(code)
        return .none
    }

    func connectButtonTapped(state: inout State) -> Effect<Action> {
        guard state.isConnectEnabled else { return .none }
        let code = state.code
        state.isConnecting = true
        state.toast = nil
        return .run { [coupleClient] send in
            do {
                let couple = try await coupleClient.connect(code)
                await send(.connectResponse(.success(couple)))
            } catch {
                await send(.connectResponse(.failure(mapCoupleError(error))))
            }
        }
    }

    func connectResponse(
        _ result: Result<Couple, CoupleError>,
        state: inout State
    ) -> Effect<Action> {
        state.isConnecting = false
        switch result {
        case let .success(couple):
            state.connectedCouple = couple
            state.path.append(.complete)
            return .none
        case let .failure(error):
            return handleConnectFailure(error, state: &state)
        }
    }

    func handleConnectFailure(
        _ error: CoupleError,
        state: inout State
    ) -> Effect<Action> {
        switch error {
        case .invalidInviteCode:
            state.toast = .error("유효하지 않은 코드에요. 다시 확인해주세요")
            return .none
        case .alreadyConnected:
            state.toast = .error("이미 커플로 연결되어 있어요.")
            return .none
        case .rateLimited:
            state.toast = .error("요청이 많아요. 잠시 후 다시 시도해 주세요.")
            return .none
        case .network:
            state.toast = .error("네트워크 연결을 확인해 주세요.")
            return .none
        case .unauthorized:
            return .send(.delegate(.sessionExpired))
        case .unknown:
            state.toast = .error("잠시 후 다시 시도해 주세요.")
            return .none
        }
    }
}

/// 영문·숫자만 남기고 대문자로 올린 뒤 앞 5자만 취한다. 붙여넣기도 같은 경로를 탄다
private func normalizedCode(_ raw: String) -> String {
    let filtered = raw.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
    return String(filtered.uppercased().prefix(CoupleConnectFeature.codeLength))
}

private func mapCoupleError(_ error: Error) -> CoupleError {
    error as? CoupleError ?? .unknown
}
