import SwiftUI
import ThirdParty

public struct AppCoordinatorView: View {
    @Bindable public var store: StoreOf<AppCoordinatorFeature>

    public init(store: StoreOf<AppCoordinatorFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.phase {
            case .bootstrapping:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loggedOut:
                if let authStore = store.scope(state: \.loggedOutAuth, action: \.auth) {
                    AuthView(store: authStore)
                }
            case .main:
                if let mainStore = store.scope(state: \.mainTab, action: \.mainTab) {
                    MainTabView(store: mainStore)
                }
            }
        }
        .overlay {
            OverlayView(store: store.scope(state: \.overlay, action: \.overlay))
        }
        .task {
            store.send(.onAppear)
        }
        .onOpenURL { url in
            store.send(.deepLinkReceived(url))
        }
    }
}
