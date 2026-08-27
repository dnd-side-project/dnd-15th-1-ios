import Domain
import SharedDesignSystem
import SwiftUI

/// 게시글에 딸린 장소 한 행. 시안 `353×56`, 배경 `#F5F5F5`, 반지름 12
struct PostPlaceRow: View {
    let place: PostDetailPlace
    /// 화면 안 북마크. 서버 값 `place.isSaved` 는 시트 진입 때의 값이라 안 쓴다
    let isSavedLocally: Bool
    let onTap: () -> Void
    let onBookmarkTap: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s8) {
            place.category.icon
                .resizable()
                .frame(width: PostDetailMetric.iconSize, height: PostDetailMetric.iconSize)

            Text(place.name)
                .typography(.body1M)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onBookmarkTap) {
                (isSavedLocally ? Image.bookmarkFillColor : Image.bookmarkStroke)
                    .resizable()
                    .frame(width: PostDetailMetric.iconSize, height: PostDetailMetric.iconSize)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.s20)
        // 위아래 16 과 아이콘 24 를 더하면 시안의 56 이 된다
        .frame(height: PostDetailMetric.rowHeight)
        .background(
            Color.bgSubtle,
            in: RoundedRectangle(cornerRadius: PostDetailMetric.rowCornerRadius)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

#if DEBUG
#Preview("저장됨 · 미저장") {
    VStack(spacing: Spacing.s8) {
        PostPlaceRow(
            place: PostDetailPlace(
                id: "1",
                name: "한강뷰 감성카페",
                category: .cafe,
                isSaved: true,
                coordinate: Coordinate(latitude: 37.5, longitude: 127.0)
            ),
            isSavedLocally: true,
            onTap: {},
            onBookmarkTap: {}
        )
        PostPlaceRow(
            place: PostDetailPlace(
                id: "2",
                name: "이름이 아주 길어서 한 줄에 다 들어가지 않는 장소 이름",
                category: .food,
                isSaved: false,
                coordinate: Coordinate(latitude: 37.6, longitude: 127.1)
            ),
            isSavedLocally: false,
            onTap: {},
            onBookmarkTap: {}
        )
    }
    .padding(Spacing.s20)
}
#endif
