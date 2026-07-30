import SwiftUI
import ThirdParty

public struct AuthView: View {
    @Bindable public var store: StoreOf<AuthFeature>

    public init(store: StoreOf<AuthFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack {
            Spacer()
            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.bottom, 12)
            }
            Button(store.isLoading ? "..." : "로그인") {
                store.send(.loginButtonTapped)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isLoading)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            store.send(.onAppear)
        }
    }
}
