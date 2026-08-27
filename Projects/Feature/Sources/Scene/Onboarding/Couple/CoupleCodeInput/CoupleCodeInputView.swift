import SharedDesignSystem
import SwiftUI
import ThirdParty

struct CoupleCodeInputView: View {
    let store: StoreOf<CoupleConnectFeature>

    @State private var isCodeFocused = true

    var body: some View {
        VStack(spacing: 0) {
            // 시안 여백. 키보드가 올라와 세로가 모자라면 이 값 아래로 줄어든다
            Spacer(minLength: 0)
                .frame(maxHeight: TitleMetric.topSpacing)

            Text("코드를 입력해주세요")
                .typography(.title1B)
                .foregroundStyle(Color.gray900)
                .multilineTextAlignment(.center)
                // 없으면 VStack 이 여백보다 제목 줄을 먼저 지운다
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
                .frame(maxHeight: CodeFieldMetric.topSpacing)

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
                    // 화면이 밀려나기 전에 내려야 한다. 전환이 시작된 뒤에 내리면 iOS 가 되돌린다
                    isCodeFocused = false
                    dismissKeyboard()
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
        .toolbar {
            backToolbar
            ToolbarItem(placement: .principal) {
                Text("커플 연결")
                    .typography(.body1SB)
                    .foregroundStyle(Color.gray900)
            }
        }
        // 연결 중에는 입력칸이 disabled 라 포커스가 풀린다.
        // 실패로 끝나면 되돌리고, 성공은 완료 화면이 푸시되므로 켜지 않는다
        .onChange(of: store.isConnecting) { _, isConnecting in
            if !isConnecting, store.connectedCouple == nil {
                isCodeFocused = true
            }
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
