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
            VStack(spacing: LogoMetric.captionSpacing) {
                logo
                headline
            }
            .padding(.top, LogoMetric.topPadding)
            .padding(.horizontal, LogoMetric.horizontalPadding)
            .padding(.bottom, LogoMetric.bottomPadding)

            Spacer(minLength: 0)

            illustration
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

    private var logo: some View {
        Image.brandWordmark
            .resizable()
            .scaledToFit()
            .frame(height: LogoMetric.height)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headline: some View {
        Text("우리 둘만의 데이트 장소 저장부터 코스짜기까지")
            .typography(.body1SB)
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var illustration: some View {
        Image.authIllustration
            .resizable()
            .aspectRatio(
                IllustrationMetric.width / IllustrationMetric.height,
                contentMode: .fit
            )
            .frame(maxWidth: IllustrationMetric.width)
            .padding(.horizontal, IllustrationMetric.horizontalPadding)
    }
}

private enum LogoMetric {
    static let topPadding: CGFloat = 80
    static let horizontalPadding: CGFloat = 20
    static let captionSpacing: CGFloat = 10
    static let bottomPadding: CGFloat = 40
    static let height: CGFloat = 73.36
}

private enum IllustrationMetric {
    static let width: CGFloat = 340
    static let height: CGFloat = 300
    static let horizontalPadding: CGFloat = 26.5
}

private enum LoginButtonMetric {
    static let buttonSpacing: CGFloat = 8
    static let padding: CGFloat = 20
}

private enum TermsMetric {
    static let bottomPadding: CGFloat = 20
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
