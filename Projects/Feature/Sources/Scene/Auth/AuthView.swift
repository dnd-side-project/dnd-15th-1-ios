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
                .padding(.top, LogoMetric.topPadding)
                .padding(.horizontal, LogoMetric.horizontalPadding)
                .padding(.bottom, LogoMetric.bottomPadding)

            Spacer(minLength: 0)

            illustrationPlaceholder
                .layoutPriority(-1)

            Spacer(minLength: 0)

            VStack(spacing: LoginButtonMetric.buttonSpacing) {
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
            .padding(LoginButtonMetric.padding)

            TermsLinksView { terms in
                store.send(.termsLinkTapped(terms))
            }
            .padding(.bottom, TermsMetric.bottomPadding)
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
            .frame(width: LogoMetric.width, height: LogoMetric.height)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var illustrationPlaceholder: some View {
        RoundedRectangle(cornerRadius: IllustrationMetric.cornerRadius)
            .fill(Color.gray200)
            .aspectRatio(340 / 300, contentMode: .fit)
            .padding(.horizontal, IllustrationMetric.horizontalPadding)
    }
}

private enum LogoMetric {
    static let topPadding: CGFloat = 40
    static let horizontalPadding: CGFloat = 20
    static let bottomPadding: CGFloat = 10
    static let width: CGFloat = 165
    static let height: CGFloat = 80
}

private enum IllustrationMetric {
    static let cornerRadius: CGFloat = 20
    static let horizontalPadding: CGFloat = 26.5
}

private enum LoginButtonMetric {
    static let buttonSpacing: CGFloat = 8
    static let padding: CGFloat = 20
}

private enum TermsMetric {
    static let bottomPadding: CGFloat = 24
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
