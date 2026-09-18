import CoreUserAnalytics
import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

struct CoupleCompleteView: View {
    let store: StoreOf<CoupleConnectFeature>

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: ArtworkMetric.topSpacing) {
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
        VStack(spacing: TitleMetric.lineSpacing) {
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
        VStack(spacing: ArtworkMetric.pillSpacing) {
            Image.coupleConnectComplete
                .resizable()
                .scaledToFit()

            nicknamePill
        }
        .padding(.horizontal, ArtworkMetric.horizontalPadding)
    }

    private var nicknamePill: some View {
        HStack(spacing: NicknamePillMetric.contentSpacing) {
            Text(store.myNickname)
                .typography(.body1SB)
                .analyticsMasked()

            Image.heart
                .renderingMode(.template)
                .resizable()
                .frame(width: NicknamePillMetric.heartSize, height: NicknamePillMetric.heartSize)

            Text(store.partnerNickname)
                .typography(.body1SB)
                .analyticsMasked()
        }
        .foregroundStyle(Color.commonWhite)
        .padding(.horizontal, NicknamePillMetric.horizontalPadding)
        .padding(.vertical, NicknamePillMetric.verticalPadding)
        .background(Color.primaryPink)
        .clipShape(Capsule())
    }
}

private enum TitleMetric {
    static let lineSpacing: CGFloat = 4
}

private enum ArtworkMetric {
    static let topSpacing: CGFloat = 24
    static let pillSpacing: CGFloat = 20
    static let horizontalPadding: CGFloat = 20
}

private enum NicknamePillMetric {
    static let contentSpacing: CGFloat = 2
    static let heartSize: CGFloat = 20
    static let horizontalPadding: CGFloat = 18
    static let verticalPadding: CGFloat = 8
}

#if DEBUG
private let previewPartner = CoupleMember(nickname: "픽둘", iconID: 1)

#Preview("연결 완료") {
    NavigationStack {
        CoupleCompleteView(
            store: Store(
                initialState: CoupleConnectFeature.State(
                    myNickname: "둘픽",
                    connectedPartner: previewPartner
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
                    connectedPartner: CoupleMember(nickname: "여섯글자상대", iconID: 1)
                )
            ) {
                CoupleConnectFeature()
            }
        )
    }
}
#endif
