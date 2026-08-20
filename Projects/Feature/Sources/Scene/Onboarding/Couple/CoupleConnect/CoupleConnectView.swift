import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct CoupleConnectView: View {
    @Bindable public var store: StoreOf<CoupleConnectFeature>

    private let shareButtonStyle = AppButtonStyle(variant: .outlined, size: .xl, fullWidth: true)

    public init(store: StoreOf<CoupleConnectFeature>) {
        self.store = store
    }

    public var body: some View {
        rootContent
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
            .onAppear {
                store.send(.onAppear)
            }
            .modal(isPresented: skipConfirmBinding) {
                ModalContent(
                    title: "다음과 같은 둘픽의 기능들을 사용할 수 없어요!",
                    content: "괜찮으신가요?",
                    image: Image.coupleConnectModal.resizable(),
                    primaryTitle: "연결할게요",
                    primaryAction: { store.send(.skipConfirmDismissed) },
                    secondaryTitle: "네",
                    secondaryAction: { store.send(.skipConfirmed) }
                )
            }
    }

    private var rootContent: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: TitleMetric.topSpacing)

            Text("커플 연결 시작하기")
                .typography(.title1B)
                .foregroundStyle(Color.gray900)
                .multilineTextAlignment(.center)

            Spacer()
                .frame(height: IllustrationMetric.topSpacing)

            Image.coupleConnectBefore
                .resizable()
                .scaledToFit()
                .frame(maxWidth: IllustrationMetric.maxWidth, maxHeight: IllustrationMetric.maxHeight)
                .padding(.horizontal, IllustrationMetric.horizontalPadding)

            Spacer()
                .frame(height: CodeMetric.topSpacing)

            VStack(spacing: CodeMetric.chipSpacing) {
                codeChip
                codeValue
            }

            Spacer(minLength: 0)

            CTAContainer {
                if store.showsSkip {
                    skipButton
                }
                shareButton
                connectButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDefault)
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

    private var codeChip: some View {
        Text("내 코드")
            .typography(.body1M)
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, CodeChipMetric.horizontalPadding)
            .frame(height: CodeChipMetric.height)
            .background(Color.gray100)
            .clipShape(RoundedRectangle(cornerRadius: CodeChipMetric.cornerRadius))
    }

    @ViewBuilder
    private var codeValue: some View {
        if let inviteCode = store.inviteCode {
            Text(inviteCode.value)
                .typography(.largeTitleB)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
        } else if let inviteCodeError = store.inviteCodeError {
            inviteCodeFailure(inviteCodeError)
            // 아직 요청 전이면 .task 가 도는 첫 프레임에 실패 UI 가 번쩍이므로 시머로 덮는다
        } else if store.isLoadingInviteCode || !store.hasAttemptedInviteCode {
            ShimmerBlock(cornerRadius: CodePlaceholderMetric.cornerRadius)
                .frame(
                    width: CodePlaceholderMetric.width,
                    height: CodePlaceholderMetric.height
                )
        } else {
            // 세션 만료처럼 값도 에러도 없이 끝난 경우까지 시머가 돌지 않게 한다
            inviteCodeFailure("코드를 불러오지 못했어요")
        }
    }

    // AppButtonStyle 의 .lg 는 h48 이지만 radius 가 12 라 시안(8)과 달라 토큰만 빌려 직접 그린다
    private func inviteCodeFailure(_ message: String) -> some View {
        VStack(spacing: RetryButtonMetric.messageSpacing) {
            Button {
                store.send(.retryInviteCodeButtonTapped)
            } label: {
                Text("다시 시도")
                    .typography(.body1SB)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, RetryButtonMetric.horizontalPadding)
                    .frame(height: RetryButtonMetric.height)
                    .background(Color.commonWhite)
                    .clipShape(RoundedRectangle(cornerRadius: RetryButtonMetric.cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: RetryButtonMetric.cornerRadius)
                            .strokeBorder(Color.borderDefault, lineWidth: RetryButtonMetric.borderWidth)
                    }
            }
            .buttonStyle(.plain)

            Text(message)
                .typography(.caption1M)
                .foregroundStyle(Color.gray400)
                .multilineTextAlignment(.center)
        }
    }

    private var skipButton: some View {
        Button {
            store.send(.skipButtonTapped)
        } label: {
            Text("다음에 연결할게요")
                .typography(.body1SB)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: SkipButtonMetric.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // 코드를 아직 못 받았으면 공유할 대상이 없어 눌리지 않는 Button 으로 모양만 유지한다
    @ViewBuilder
    private var shareButton: some View {
        if let shareURL = store.inviteCode?.shareURL {
            ShareLink(item: shareURL) {
                Text("코드 공유하기")
            }
            .buttonStyle(shareButtonStyle)
        } else if let code = store.inviteCode?.value {
            ShareLink(item: code) {
                Text("코드 공유하기")
            }
            .buttonStyle(shareButtonStyle)
        } else {
            Button {
            } label: {
                Text("코드 공유하기")
            }
            .buttonStyle(shareButtonStyle)
            .disabled(true)
        }
    }

    private var connectButton: some View {
        AppButton("상대 코드로 연결하기", style: .dark, size: .xl, fullWidth: true) {
            store.send(.codeInputButtonTapped)
        }
    }

    // dim 탭으로 닫혀도 되는 모달이라 false 가 들어오면 그대로 닫기 액션을 보낸다
    private var skipConfirmBinding: Binding<Bool> {
        Binding(
            get: { store.isSkipConfirmPresented },
            set: { newValue in
                if !newValue {
                    store.send(.skipConfirmDismissed)
                }
            }
        )
    }
}

private enum BackButtonMetric {
    static let iconSize: CGFloat = 24
}

private enum TitleMetric {
    static let topSpacing: CGFloat = 65.5
}

private enum IllustrationMetric {
    static let topSpacing: CGFloat = 20
    static let maxWidth: CGFloat = 353
    static let maxHeight: CGFloat = 100
    static let horizontalPadding: CGFloat = 20
}

private enum CodeMetric {
    static let topSpacing: CGFloat = 60
    static let chipSpacing: CGFloat = 8
}

private enum CodeChipMetric {
    static let horizontalPadding: CGFloat = 12
    static let height: CGFloat = 32
    static let cornerRadius: CGFloat = 8
}

// 코드 자리표시자. 로딩 시머와 실패 후 재시도 블록이 같은 치수를 쓴다
private enum CodePlaceholderMetric {
    static let width: CGFloat = 160
    static let height: CGFloat = 48
    static let cornerRadius: CGFloat = 8
}

private enum RetryButtonMetric {
    static let messageSpacing: CGFloat = 6
    static let horizontalPadding: CGFloat = 24
    static let height: CGFloat = CodePlaceholderMetric.height
    static let cornerRadius: CGFloat = CodePlaceholderMetric.cornerRadius
    static let borderWidth: CGFloat = 1
}

private enum SkipButtonMetric {
    static let height: CGFloat = 32
}

#if DEBUG
#Preview("코드 로딩") {
    NavigationStack {
        CoupleConnectView(
            store: Store(
                initialState: CoupleConnectFeature.State(
                    myNickname: "둘픽",
                    isLoadingInviteCode: true
                )
            ) {
                CoupleConnectFeature()
            }
        )
    }
}

#Preview("코드 표시") {
    NavigationStack {
        CoupleConnectView(
            store: Store(
                initialState: CoupleConnectFeature.State(
                    myNickname: "둘픽",
                    inviteCode: InviteCode(value: "AB12C", shareURL: nil)
                )
            ) {
                CoupleConnectFeature()
            }
        )
    }
}

#Preview("코드 실패 · 네트워크") {
    NavigationStack {
        CoupleConnectView(
            store: Store(
                initialState: CoupleConnectFeature.State(
                    myNickname: "둘픽",
                    inviteCodeError: "네트워크 연결을 확인해 주세요"
                )
            ) {
                CoupleConnectFeature()
            }
        )
    }
}

#Preview("코드 실패 · 알 수 없음") {
    NavigationStack {
        CoupleConnectView(
            store: Store(
                initialState: CoupleConnectFeature.State(
                    myNickname: "둘픽",
                    inviteCodeError: "잠시 후 다시 시도해 주세요"
                )
            ) {
                CoupleConnectFeature()
            }
        )
    }
}

#Preview("스킵 확인") {
    NavigationStack {
        CoupleConnectView(
            store: Store(
                initialState: CoupleConnectFeature.State(
                    myNickname: "둘픽",
                    inviteCode: InviteCode(value: "AB12C", shareURL: nil),
                    isSkipConfirmPresented: true
                )
            ) {
                CoupleConnectFeature()
            }
        )
    }
}
#endif
