import Domain
import SwiftUI
import ThirdParty

public struct MyPageView: View {
    @Bindable public var store: StoreOf<MyPageFeature>

    public init(store: StoreOf<MyPageFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 12) {
            Spacer()

            if let user = store.user {
                Text(user.id)
                    .font(.headline)
            } else {
                Text("마이페이지")
                    .font(.headline)
            }

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(store.isLoading ? "..." : "로그아웃") {
                store.send(.logoutButtonTapped)
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
