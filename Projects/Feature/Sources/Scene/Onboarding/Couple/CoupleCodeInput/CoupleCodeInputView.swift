import SharedDesignSystem
import SwiftUI
import ThirdParty

struct CoupleCodeInputView: View {
    let store: StoreOf<CoupleConnectFeature>

    @State private var isCodeFocused = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: TitleMetric.topSpacing)

            Text("코드를 입력해주세요")
                .typography(.title1B)
                .foregroundStyle(Color.gray900)
                .multilineTextAlignment(.center)

            Spacer()
                .frame(height: CodeFieldMetric.topSpacing)

            CodeInputField(
                code: codeBinding,
                isFocused: $isCodeFocused,
                length: CoupleConnectFeature.codeLength
            )
            .disabled(store.isConnecting)
            .padding(.horizontal, CodeFieldMetric.horizontalPadding)

            Spacer(minLength: 0)

            CTAContainer {
                AppButton("연결하기", style: .dark, size: .xl, fullWidth: true) {
                    store.send(.connectButtonTapped)
                }
                .disabled(!store.isConnectEnabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDefault)
        .toast(item: toastBinding, bottomInset: ToastMetric.bottomInset)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onChange(of: scenePhase) { _, newPhase in
            // 상대가 이미 연결했으면 내가 코드를 넣어도 실패한다. 돌아온 순간 넘겨준다
            guard newPhase == .active else { return }
            store.send(.sceneBecameActive)
        }
        .toolbar {
            backToolbar
            ToolbarItem(placement: .principal) {
                Text("커플 연결")
                    .typography(.body1SB)
                    .foregroundStyle(Color.gray900)
            }
        }
        // push 애니메이션 중에 준 포커스는 버려진다. 전환이 끝난 뒤에 준다
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            isCodeFocused = true
        }
        // 연결 중에는 입력칸이 disabled 라 포커스가 풀린다. 끝나면 되돌린다
        .onChange(of: store.isConnecting) { _, isConnecting in
            isCodeFocused = !isConnecting
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

    private var codeBinding: Binding<String> {
        Binding(
            get: { store.code },
            set: { store.send(.codeChanged($0)) }
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
}

private enum BackButtonMetric {
    static let iconSize: CGFloat = 24
}

private enum TitleMetric {
    static let topSpacing: CGFloat = 62.5
}

private enum CodeFieldMetric {
    static let topSpacing: CGFloat = 32
    static let horizontalPadding: CGFloat = 20
}

private enum ToastMetric {
    // CTA 는 "연결하기" 하나뿐이다
    static let bottomInset: CGFloat = CTALayout.toastInset(buttonHeights: [CTALayout.xlButtonHeight])
}

#if DEBUG
#Preview("입력 전") {
    NavigationStack {
        CoupleCodeInputView(
            store: Store(
                initialState: CoupleConnectFeature.State(myNickname: "둘픽")
            ) {
                CoupleConnectFeature()
            }
        )
    }
}

#Preview("입력 완료") {
    NavigationStack {
        CoupleCodeInputView(
            store: Store(
                initialState: CoupleConnectFeature.State(
                    myNickname: "둘픽",
                    code: "AB12C"
                )
            ) {
                CoupleConnectFeature()
            }
        )
    }
}

#Preview("에러 토스트") {
    NavigationStack {
        CoupleCodeInputView(
            store: Store(
                initialState: CoupleConnectFeature.State(
                    myNickname: "둘픽",
                    code: "AB12C",
                    toast: .error("유효하지 않은 코드에요. 다시 확인해주세요")
                )
            ) {
                CoupleConnectFeature()
            }
        )
    }
}
#endif
