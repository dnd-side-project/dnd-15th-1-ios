import Domain
import Foundation
import SharedDesignSystem
import ThirdParty

@Reducer
public struct CoupleConnectFeature {
    /// 초대 코드 자릿수. 다 차야 CTA 가 열리고 자동 제출은 없다
    static let codeLength = 5

    /// 영문·숫자만 남기고 대문자로 올린 뒤 자릿수만큼 자른다. 붙여넣기도 같은 경로를 탄다
    static func normalizedCode(_ raw: String) -> String {
        let filtered = raw.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return String(filtered.uppercased().prefix(codeLength))
    }

    @ObservableState
    public struct State: Equatable {
        public var myNickname: String
        // 온보딩은 skip 을 보여주고, 홈 진입은 숨긴다
        public var showsSkip: Bool
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
            showsSkip: Bool = true,
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
            self.showsSkip = showsSkip
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
        case dismissToast
        case delegate(Delegate)

        /// 앞 세 개는 커플 구간 안에서의 화면 전환 요청이고, `connected` / `skipped` 는 구간을 벗어난다
        @CasePathable
        public enum Delegate: Equatable {
            case showCodeInput
            case showComplete
            case back
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
            case .codeInputButtonTapped: return codeInputButtonTapped()
            case let .codeChanged(code): return codeChanged(code, state: &state)
            case .connectButtonTapped: return connectButtonTapped(state: &state)
            case let .connectResponse(result): return connectResponse(result, state: &state)
            case .completeButtonTapped: return completeButtonTapped(state: &state)
            case .backButtonTapped: return backButtonTapped(state: &state)
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

    func codeInputButtonTapped() -> Effect<Action> {
        .send(.delegate(.showCodeInput))
    }

    func completeButtonTapped(state: inout State) -> Effect<Action> {
        guard let couple = state.connectedCouple else { return .none }
        return .send(.delegate(.connected(couple)))
    }

    func backButtonTapped(state: inout State) -> Effect<Action> {
        // 이전 화면에서 띄운 알림은 경로가 바뀌면 더 이상 유효하지 않다
        state.toast = nil
        return .send(.delegate(.back))
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
        // 입력칸이 잠겼다 풀리면 텍스트필드가 같은 값을 그대로 돌려보낸다.
        // 그걸 입력으로 치면 방금 띄운 실패 메시지가 바로 지워진다
        let normalized = Self.normalizedCode(code)
        guard normalized != state.code else { return .none }
        // 코드를 고치면 실패 메시지도 같이 사라진다
        state.toast = nil
        state.code = normalized
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
            return .send(.delegate(.showComplete))
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

private func mapCoupleError(_ error: Error) -> CoupleError {
    error as? CoupleError ?? .unknown
}
