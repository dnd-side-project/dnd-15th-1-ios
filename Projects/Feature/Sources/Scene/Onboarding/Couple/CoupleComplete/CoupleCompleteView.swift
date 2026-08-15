import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

struct CoupleCompleteView: View {
    let store: StoreOf<CoupleConnectFeature>

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                titles
                artwork
            }

            Spacer(minLength: 0)

            CTAContainer {
                AppButton("확인", style: .dark, size: .xl, fullWidth: true) {
                    store.send(.completeButtonTapped)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDefault)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private var titles: some View {
        VStack(spacing: 4) {
            Text("커플 연결이 완료되었어요")
                .typography(.title3SB)
                .foregroundStyle(Color.textTertiary)

            Text("지금 바로 둘픽을 즐겨볼까요?")
                .typography(.title1B)
                .foregroundStyle(Color.gray900)
        }
        .multilineTextAlignment(.center)
    }

    private var artwork: some View {
        VStack(spacing: 20) {
            Image.coupleConnectComplete
                .resizable()
                .scaledToFit()

            nicknamePill
        }
        .padding(.horizontal, 20)
    }

    private var nicknamePill: some View {
        HStack(spacing: 2) {
            Text(store.myNickname)
                .typography(.body1SB)

            Image.heart
                .renderingMode(.template)
                .resizable()
                .frame(width: 20, height: 20)

            Text(store.partnerNickname)
                .typography(.body1SB)
        }
        .foregroundStyle(Color.commonWhite)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color.primaryPink)
        .clipShape(Capsule())
    }
}

#if DEBUG
private let previewCouple = Couple(
    partnerNickname: "픽둘",
    partnerIconID: 1
)

#Preview("연결 완료") {
    NavigationStack {
        CoupleCompleteView(
            store: Store(
                initialState: CoupleConnectFeature.State(
                    myNickname: "둘픽",
                    connectedCouple: previewCouple
                )
            ) {
                CoupleConnectFeature()
            }
        )
    }
}

#Preview("긴 닉네임") {
    NavigationStack {
        CoupleCompleteView(
            store: Store(
                initialState: CoupleConnectFeature.State(
                    myNickname: "여섯글자닉넴",
                    connectedCouple: Couple(
                        partnerNickname: "여섯글자상대",
                        partnerIconID: 1
                    )
                )
            ) {
                CoupleConnectFeature()
            }
        )
    }
}
#endif
