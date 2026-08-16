import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct NicknameView: View {
    // CTA 는 "다음" 하나뿐이다
    static let toastInset = CTALayout.toastInset(buttonHeights: [CTALayout.xlButtonHeight])

    @Bindable public var store: StoreOf<NicknameFeature>

    @State private var isNicknameFocused = false

    public init(store: StoreOf<NicknameFeature>) {
        self.store = store
    }

    public var body: some View {
        rootContent
            .navigationTitle("닉네임 설정")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar { backToolbar }
            // 약관을 다 읽고 나면 바로 닉네임을 치게 한다. 시트가 뜰 때는 건드리지 않는다
            .onChange(of: store.isTermsSheetPresented) { _, isPresented in
                if !isPresented {
                    isNicknameFocused = true
                }
            }
            // push 로 밀려나도 화면은 스택에 남아 입력 포커스를 쥐고 있다. 돌아왔을 때 키보드가 되살아나지 않게 여기서 놓는다.
            // 바인딩만으로는 입력칸이 건너뛸 수 있어 편집도 함께 끊는다
            .onDisappear {
                isNicknameFocused = false
                dismissKeyboard()
            }
            .toast(item: toastBinding, bottomInset: Self.toastInset)
            .sheet(item: presentedTermsBinding) { terms in
                if let url = terms.url {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
            .bottomSheet(isPresented: termsSheetBinding, isDismissable: false) {
                TermsAgreementSheet(store: store)
            }
    }

    private var rootContent: some View {
        VStack(spacing: 0) {
            // 시안 여백. 키보드가 올라와 세로가 모자라면 이 값 아래로 줄어든다
            Spacer(minLength: 0)
                .frame(maxHeight: TitleMetric.topSpacing)

            Text("둘픽에서 사용할 닉네임을 알려주세요")
                .typography(.title1B)
                .foregroundStyle(Color.gray900)
                .multilineTextAlignment(.center)
                .frame(maxWidth: TitleMetric.maxWidth)
                // 없으면 VStack 이 여백보다 제목 줄을 먼저 지운다
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
                .frame(maxHeight: NicknameFieldMetric.topSpacing)

            AppTextField(
                text: $store.nickname,
                placeholder: "최대 6글자",
                size: .large,
                style: .filled,
                errorMessage: store.lengthError ?? store.inlineError,
                // 입력칸이 공백과 여덟 번째 글자를 아예 받지 않는다
                sanitize: NicknameFeature.sanitizedNickname,
                isFocused: $isNicknameFocused,
                onSubmit: { isNicknameFocused = false }
            )
            .padding(.horizontal, NicknameFieldMetric.horizontalPadding)

            Spacer(minLength: 0)

            nextButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDefault)
    }

    private var nextButton: some View {
        CTAContainer {
            AppButton("다음", style: .dark, size: .xl, fullWidth: true) {
                // 화면이 밀려나기 전에 내려야 한다. 전환이 시작된 뒤에 내리면 iOS 가 되돌린다
                isNicknameFocused = false
                dismissKeyboard()
                store.send(.nextButtonTapped)
            }
            .disabled(!store.isNextEnabled)
        }
    }

    @ToolbarContentBuilder
    private var backToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                store.send(.backButtonTapped)
            } label: {
                Image.arrowLeft
                    .renderingMode(.original)
                    .resizable()
                    .frame(width: BackButtonMetric.iconSize, height: BackButtonMetric.iconSize)
            }
        }
    }

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
                    store.send(.dismissTermsDetail)
                }
            }
        )
    }

    // isDismissable: false 라 컴포넌트가 값을 되돌려주지 않는다. 닫기는 CTA 액션으로만 일어난다
    private var termsSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isTermsSheetPresented },
            set: { _ in }
        )
    }
}

private enum BackButtonMetric {
    static let iconSize: CGFloat = 24
}

private enum TitleMetric {
    static let topSpacing: CGFloat = 120
    static let maxWidth: CGFloat = 240
}

private enum NicknameFieldMetric {
    static let topSpacing: CGFloat = 60
    static let horizontalPadding: CGFloat = 20
}

#if DEBUG
#Preview("약관 시트") {
    NavigationStack {
        NicknameView(
            store: Store(initialState: NicknameFeature.State()) {
                NicknameFeature()
            }
        )
    }
}

#Preview("입력 전") {
    NavigationStack {
        NicknameView(
            store: Store(
                initialState: NicknameFeature.State(isTermsSheetPresented: false)
            ) {
                NicknameFeature()
            }
        )
    }
}

#Preview("길이 초과") {
    NavigationStack {
        NicknameView(
            store: Store(
                initialState: NicknameFeature.State(
                    nickname: "일곱글자닉네임",
                    isTermsSheetPresented: false
                )
            ) {
                NicknameFeature()
            }
        )
    }
}

// 토스트는 3초 뒤 스스로 사라진다. 다시 보려면 프리뷰를 새로 고친다
#Preview("네트워크 실패") {
    NavigationStack {
        NicknameView(
            store: Store(
                initialState: NicknameFeature.State(
                    nickname: "둘픽커플",
                    toast: .error("네트워크 연결을 확인해 주세요."),
                    isTermsSheetPresented: false
                )
            ) {
                NicknameFeature()
            }
        )
    }
}

#Preview("닉네임 거절") {
    NavigationStack {
        NicknameView(
            store: Store(
                initialState: NicknameFeature.State(
                    nickname: "둘픽커플",
                    inlineError: "사용할 수 없는 닉네임이에요",
                    isTermsSheetPresented: false
                )
            ) {
                NicknameFeature()
            }
        )
    }
}
#endif
