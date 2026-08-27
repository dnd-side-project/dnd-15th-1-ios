import Foundation
import ThirdParty

@Reducer
public struct OverlayFeature {
    @ObservableState
    public struct State: Equatable {
        public var toastMessage: String?
        public var alertMessage: String?

        public init(
            toastMessage: String? = nil,
            alertMessage: String? = nil
        ) {
            self.toastMessage = toastMessage
            self.alertMessage = alertMessage
        }
    }

    public enum Action: Equatable {
        case showToast(String)
        case dismissToast
        case showAlert(String)
        case dismissAlert
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .showToast(message):
                state.toastMessage = message
                return .none
            case .dismissToast:
                state.toastMessage = nil
                return .none
            case let .showAlert(message):
                state.alertMessage = message
                return .none
            case .dismissAlert:
                state.alertMessage = nil
                return .none
            }
        }
    }
}
