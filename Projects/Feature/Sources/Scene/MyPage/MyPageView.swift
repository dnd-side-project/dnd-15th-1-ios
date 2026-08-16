import Domain
import SwiftUI
import ThirdParty

public struct MyPageView: View {
    @Bindable public var store: StoreOf<MyPageFeature>

    public init(store: StoreOf<MyPageFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: ContentMetric.spacing) {
            Spacer()

            if let userID = store.userID {
                Text(userID)
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
            .padding(.horizontal, LogoutButtonMetric.horizontalPadding)
            .padding(.bottom, LogoutButtonMetric.bottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            store.send(.onAppear)
        }
    }
}

private enum ContentMetric {
    static let spacing: CGFloat = 12
}

private enum LogoutButtonMetric {
    static let horizontalPadding: CGFloat = 20
    static let bottomPadding: CGFloat = 24
}
