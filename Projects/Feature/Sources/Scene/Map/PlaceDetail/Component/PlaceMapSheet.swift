import CoreUserAnalytics
import SharedDesignSystem
import SwiftUI

/// 「지도로 보기」 시트 내용. `.bottomSheet` 가 올린다. 시안 「장소 상세 - 지도 연결」.
/// 고른 앱은 기억하지 않아 두 줄을 늘 보인다
struct PlaceMapSheet: View {
    /// 헤더와 같은 이름. 별칭이 먼저다
    let title: String
    /// 별칭이면 녹화에서 가린다
    let isAlias: Bool
    let onSelect: (PlaceMapApp) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            appList
        }
    }
}

private extension PlaceMapSheet {
    /// 시안 「text area」 위아래 여백. 맞는 간격 토큰이 없다
    static let headerTextVerticalInset: CGFloat = 5

    var header: some View {
        HStack(alignment: .top, spacing: Spacing.s8) {
            VStack(alignment: .leading, spacing: 0) {
                Text("지도로 보기")
                    .typography(.title3SB)
                    .foregroundStyle(Color.textPrimary)
                    .frame(minHeight: Typography.title3SB.lineHeight)
                placeRow
            }
            .padding(.vertical, Self.headerTextVerticalInset)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { onClose() } label: {
                Image.x
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
        }
        .padding(.leading, Spacing.s20)
        .padding(.trailing, Spacing.s12)
    }

    var placeRow: some View {
        HStack(spacing: Spacing.s4) {
            Image.mapPin
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
            Text(title)
                .typography(.body2M)
                .lineLimit(1)
                .frame(minHeight: Typography.body2M.lineHeight)
                .analyticsMasked(isAlias)
        }
        .foregroundStyle(Color.textTertiary)
    }

    var appList: some View {
        VStack(spacing: Spacing.s8) {
            ForEach(PlaceMapApp.allCases, id: \.self) { app in
                appRow(app)
            }
        }
        .padding(Spacing.s20)
    }

    func appRow(_ app: PlaceMapApp) -> some View {
        Button { onSelect(app) } label: {
            HStack(spacing: Spacing.s8) {
                app.sheetLogo
                    .resizable()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text(app.sheetTitle)
                    .typography(.body1M)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .frame(minHeight: Typography.body1M.lineHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image.chevronRight
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.vertical, Spacing.s16)
            .padding(.horizontal, Spacing.s20)
            .background(Color.bgSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension PlaceMapApp {
    var sheetTitle: String {
        switch self {
        case .naver: "네이버 지도로 보기"
        case .kakao: "카카오맵으로 보기"
        }
    }

    var sheetLogo: Image {
        switch self {
        case .naver: .naverMap
        case .kakao: .kakaoMap
        }
    }
}
