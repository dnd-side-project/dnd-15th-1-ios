import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct NicknameView: View {
    @Bindable public var store: StoreOf<NicknameFeature>

    public init(store: StoreOf<NicknameFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            rootContent
                .navigationTitle("닉네임 설정")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { backToolbar }
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
        .bottomSheet(isPresented: termsSheetBinding, isDismissable: false) {
            TermsAgreementSheet(store: store)
        }
    }

    private var rootContent: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 120)

            Text("둘픽에서 사용할 닉네임을 알려주세요")
                .typography(.title1B)
                .foregroundStyle(Color.gray900)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)

            Spacer()
                .frame(height: 60)

            AppTextField(
                text: nicknameBinding,
                placeholder: "최대 6글자",
                size: .large,
                style: .filled,
                errorMessage: store.lengthError ?? store.inlineError
            )
            .padding(.horizontal, 20)

            Spacer(minLength: 0)

            CTAContainer {
                AppButton("다음", style: .dark, size: .xl, fullWidth: true) {
                    store.send(.nextButtonTapped)
                }
                .disabled(!store.isNextEnabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDefault)
    }

    @ToolbarContentBuilder
    private var backToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                // 시안대로 자리만 둔다. 실제 pop 은 상위 네비게이션이 붙인다
            } label: {
                Image.arrowLeft
                    .renderingMode(.original)
                    .resizable()
                    .frame(width: 24, height: 24)
            }
        }
    }

    private var nicknameBinding: Binding<String> {
        Binding(
            get: { store.nickname },
            set: { store.send(.nicknameChanged($0)) }
        )
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

#if DEBUG
#Preview("약관 시트") {
    NicknameView(
        store: Store(initialState: NicknameFeature.State()) {
            NicknameFeature()
        }
    )
}

#Preview("입력 전") {
    NicknameView(
        store: Store(
            initialState: NicknameFeature.State(isTermsSheetPresented: false)
        ) {
            NicknameFeature()
        }
    )
}

#Preview("길이 초과") {
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
#endif
