import Domain
import Foundation
import ThirdParty

@Reducer
public struct ConnectionManageFeature {
    @ObservableState
    public struct State: Equatable {
        public var me: CoupleMember?
        public var partner: CoupleMember?
        public var daysTogether: Int?

        public init(
            me: CoupleMember? = nil,
            partner: CoupleMember? = nil,
            daysTogether: Int? = nil
        ) {
            self.me = me
            self.partner = partner
            self.daysTogether = daysTogether
        }
    }

    public enum Action: Equatable {
        case onAppear
        case coupleLoaded(CoupleStatus)
        case disconnectTapped
    }

    @Dependency(\.coupleClient) var coupleClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
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
                // 커플 연결 끊기 API 는 이후 연결
                return .none
            }
        }
    }
}
