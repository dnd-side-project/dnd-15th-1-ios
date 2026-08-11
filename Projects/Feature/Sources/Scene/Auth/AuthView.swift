import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct AuthView: View {
    @Bindable public var store: StoreOf<AuthFeature>

    public init(store: StoreOf<AuthFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            logoPlaceholder
                .padding(.top, 40)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            Spacer(minLength: 0)

            illustrationPlaceholder
                .layoutPriority(-1)

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                ForEach(providers, id: \.self) { provider in
                    SocialLoginButton(
                        provider: provider,
                        isLoading: store.loadingProvider == provider && store.isLoading,
                        isEnabled: !store.isLoading
                    ) {
                        store.send(.loginButtonTapped(provider))
                    }
                }
            }
            .padding(20)

            TermsLinksView { terms in
                store.send(.termsLinkTapped(terms))
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.commonWhite)
        .toast(item: toastBinding)
        .sheet(item: presentedTermsBinding) { terms in
            if let url = terms.url {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .task {
            store.send(.onAppear)
        }
    }

    private var providers: [AuthProvider] { [.apple, .kakao, .google] }

    private var toastBinding: Binding<ToastState?> {
        Binding(
            get: { store.toast },
            set: { newValue in
                if newValue == nil {
                    store.send(.dismissToast)
                }
            }
        )
    }

    private var presentedTermsBinding: Binding<TermsType?> {
        Binding(
            get: { store.presentedTerms },
            set: { newValue in
                if newValue == nil {
                    store.send(.dismissTerms)
                }
            }
        )
    }

    private var logoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color(red: 50 / 255, green: 50 / 255, blue: 50 / 255))
            .frame(width: 165, height: 80)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var illustrationPlaceholder: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.gray200)
            .aspectRatio(340 / 300, contentMode: .fit)
            .padding(.horizontal, 26.5)
    }
}

#Preview("Default") {
    AuthView(
        store: Store(initialState: AuthFeature.State()) {
            AuthFeature()
        }
    )
}

#Preview("Loading") {
    AuthView(
        store: Store(
            initialState: AuthFeature.State(
                isLoading: true,
                loadingProvider: .kakao
            )
        ) {
            AuthFeature()
        }
    )
}

#Preview("Error") {
    AuthView(
        store: Store(
            initialState: AuthFeature.State(
                toast: .error("로그인에 실패했습니다.")
            )
        ) {
            AuthFeature()
        }
    )
}
