import SharedDesignSystem
import SwiftUI

// MARK: - PlaceListRowMetric

private enum PlaceListRowMetric {
    static let iconSize: CGFloat = 24
    static let thumbnailSize: CGFloat = 88
    static let thumbnailCornerRadius: CGFloat = 12
    static let dividerHeight: CGFloat = 1
    /// 글자 묶음과 우측 슬롯 사이 최소 간격. 간격 토큰에 없는 값이다.
    static let trailingGap: CGFloat = 2
    /// 썸네일 줄의 왼쪽이 아이콘이 아니라 장소명 글자에 맞는다. 그만큼 더 들어간다.
    static let textLeadingInset: CGFloat = Spacing.s20 + iconSize + Spacing.s12
}

// MARK: - PlaceListRow

/// 목록에 쓰는 장소 한 줄.
///
/// 탐색 탭의 `PlaceRow` 와 달리 카드가 아니다. 전체 폭을 쓰고 아래에 구분선이 붙는다.
///
/// 배경은 이 뷰가 칠하지 않는다. 고른 행을 연분홍으로 바꾸는 화면처럼 필요한 쪽에서 밖에서 얹는다.
///
/// ```swift
/// PlaceListRow(icon: .categoryFood, name: name, address: address) { mark }
///     .background(isSelected ? Color.brandSurface : Color.clear)
/// ```
///
/// 썸네일 칸의 크기·모서리·간격·스크롤만 이 뷰가 책임진다.
/// `URL` 을 그림으로 바꾸는 일은 이 모듈이 모른다. 부르는 쪽이 `thumbnail` 슬롯으로 준다.
///
/// ```swift
/// PlaceListRow(
///     icon: .categoryFood,
///     name: name,
///     address: address,
///     thumbnailURLs: urls
/// ) { url in
///     RemoteImage(url: url)
/// } trailing: {
///     badge
/// }
/// ```
///
/// 썸네일과 우측 슬롯은 각각 없어도 된다. 넷 다 조합할 수 있다.
///
/// ```swift
/// PlaceListRow(icon: .categoryCafe, name: name, address: address)
/// ```
///
/// `Domain` 타입을 받지 않는다. 값만 받는다.
struct PlaceListRow<Thumbnail: View, Trailing: View>: View {
    private let icon: Image
    private let name: String
    private let address: String
    private let thumbnailURLs: [URL]
    private let thumbnail: (URL) -> Thumbnail
    private let trailing: Trailing
    /// 우측 슬롯을 둘지. `false` 면 24 칸도 그 앞 여백도 만들지 않아 장소명이 남는 폭을 다 쓴다.
    private let hasTrailing: Bool

    init(
        icon: Image,
        name: String,
        address: String,
        thumbnailURLs: [URL] = [],
        @ViewBuilder thumbnail: @escaping (URL) -> Thumbnail,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            icon: icon,
            name: name,
            address: address,
            thumbnailURLs: thumbnailURLs,
            thumbnail: thumbnail,
            trailing: trailing(),
            hasTrailing: true
        )
    }

    private init(
        icon: Image,
        name: String,
        address: String,
        thumbnailURLs: [URL],
        thumbnail: @escaping (URL) -> Thumbnail,
        trailing: Trailing,
        hasTrailing: Bool
    ) {
        self.icon = icon
        self.name = name
        self.address = address
        self.thumbnailURLs = thumbnailURLs
        self.thumbnail = thumbnail
        self.trailing = trailing
        self.hasTrailing = hasTrailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            header
                // 헤더가 드롭다운처럼 자기 밖 아래로 펼치는 걸 담을 수 있다.
                // 올려두지 않으면 뒤에 그려지는 썸네일이 그 펼침을 덮는다
                .zIndex(1)

            if !thumbnailURLs.isEmpty {
                thumbnails
            }
        }
        .padding(.vertical, Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // overlay 로 걸면 자식 위에 그려져 행 메뉴를 1pt 선이 가로지른다.
        // 선 자리에는 여백뿐이라 background 로 내려도 보이는 모습은 같다
        .background(alignment: .bottom) { divider }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.s12) {
            icon
                .resizable()
                .frame(width: PlaceListRowMetric.iconSize, height: PlaceListRowMetric.iconSize)

            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .typography(.body1SB)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(address)
                    .typography(.caption1R)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }

            // 우측 슬롯이 없는 행은 앞 여백도 두지 않는다. 빈 24 칸과 그 앞 여백이 남으면 글자 폭만 줄어든다.
            Spacer(minLength: hasTrailing ? PlaceListRowMetric.trailingGap : 0)

            if hasTrailing {
                // 아이콘과 같은 높이를 확보해 장소명 줄에 맞춘다. 슬롯은 24 × 24 로 고정이다.
                trailing
                    .frame(
                        width: PlaceListRowMetric.iconSize,
                        height: PlaceListRowMetric.iconSize
                    )
            }
        }
        .padding(.horizontal, Spacing.s20)
    }

    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s4) {
                ForEach(Array(thumbnailURLs.enumerated()), id: \.offset) { _, url in
                    thumbnail(url)
                        .frame(
                            width: PlaceListRowMetric.thumbnailSize,
                            height: PlaceListRowMetric.thumbnailSize
                        )
                        // 모서리는 이 뷰가 자른다. `RemoteImage(cornerRadius:)` 로 넘겨도 픽셀이 같은데,
                        // 여기서 자르면 슬롯에 뭘 넣든 둥근 12 가 지켜진다
                        .clipShape(
                            RoundedRectangle(cornerRadius: PlaceListRowMetric.thumbnailCornerRadius)
                        )
                }
            }
            .padding(.leading, PlaceListRowMetric.textLeadingInset)
            .padding(.trailing, Spacing.s20)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.borderWeak)
            .frame(height: PlaceListRowMetric.dividerHeight)
    }
}

// MARK: - 썸네일 없는 행

extension PlaceListRow where Thumbnail == EmptyView {
    /// 사진이 없는 흔한 경우. 썸네일 줄 자체가 나오지 않는다.
    init(
        icon: Image,
        name: String,
        address: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            icon: icon,
            name: name,
            address: address,
            thumbnailURLs: [],
            thumbnail: { _ in EmptyView() },
            trailing: trailing
        )
    }
}

// MARK: - 우측 슬롯 없는 행

extension PlaceListRow where Trailing == EmptyView {
    /// 배지도 버튼도 없는 행. 슬롯 자리와 그 앞 여백을 두지 않아 장소명이 남는 폭을 다 쓴다.
    init(
        icon: Image,
        name: String,
        address: String,
        thumbnailURLs: [URL] = [],
        @ViewBuilder thumbnail: @escaping (URL) -> Thumbnail
    ) {
        self.init(
            icon: icon,
            name: name,
            address: address,
            thumbnailURLs: thumbnailURLs,
            thumbnail: thumbnail,
            trailing: EmptyView(),
            hasTrailing: false
        )
    }
}

// MARK: - 썸네일도 우측 슬롯도 없는 행

extension PlaceListRow where Thumbnail == EmptyView, Trailing == EmptyView {
    /// 아이콘 · 장소명 · 주소만 있는 가장 짧은 행.
    init(icon: Image, name: String, address: String) {
        self.init(
            icon: icon,
            name: name,
            address: address,
            thumbnailURLs: [],
            thumbnail: { _ in EmptyView() },
            trailing: EmptyView(),
            hasTrailing: false
        )
    }
}

#if DEBUG

// MARK: - Preview Fixture

private enum PlaceListRowPreview {
    static let name = "장소명"
    static let address = "경기도 안산시 모모로 145길 (뭐뭐동)"
    static let selectedBackground = Color.brandSurface

    static let thumbnailURLs: [URL] = [
        "https://picsum.photos/id/101/176",
        "https://picsum.photos/id/102/176",
        "https://picsum.photos/id/103/176",
        "https://picsum.photos/id/104/176"
    ].compactMap(URL.init(string:))

    static let markSize: CGFloat = 20
}

/// 번호 배지·선택 원의 진짜 부품은 `PlaceNumberBadge` 가 만든다. 여기서는 슬롯 확인용으로만 그린다.
private struct PlaceListRowPreviewMark: View {
    var number: Int?

    var body: some View {
        if let number {
            Text("\(number)")
                .typography(.caption2M)
                .foregroundStyle(Color.textInverse)
                .frame(width: PlaceListRowPreview.markSize, height: PlaceListRowPreview.markSize)
                .background(Color.brandPrimary, in: Circle())
        } else {
            Circle()
                .stroke(Color.borderDefault, lineWidth: 1)
                .frame(width: PlaceListRowPreview.markSize, height: PlaceListRowPreview.markSize)
        }
    }
}

// MARK: - Preview

// a08 · a10: 저장한 장소 목록. 우측이 ⋮ 더보기 버튼
#Preview("더보기 버튼") {
    PlaceListRow(
        icon: .categoryFood,
        name: PlaceListRowPreview.name,
        address: PlaceListRowPreview.address,
        thumbnailURLs: PlaceListRowPreview.thumbnailURLs
    ) { url in
        RemoteImage(url: url)
    } trailing: {
        Button {
        } label: {
            Image.menu
                .resizable()
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }
}

// b04: 코스에 넣을 장소 고르기. 아직 안 고른 빈 원
#Preview("빈 선택 원") {
    VStack(spacing: 0) {
        PlaceListRow(
            icon: .categoryFood,
            name: PlaceListRowPreview.name,
            address: PlaceListRowPreview.address,
            thumbnailURLs: PlaceListRowPreview.thumbnailURLs
        ) { url in
            RemoteImage(url: url)
        } trailing: {
            PlaceListRowPreviewMark(number: nil)
        }

        PlaceListRow(
            icon: .categoryActivity,
            name: PlaceListRowPreview.name,
            address: PlaceListRowPreview.address
        ) {
            PlaceListRowPreviewMark(number: nil)
        }
    }
}

// b06: 고른 행은 배경이 연분홍이 되고 우측에 순번이 붙는다. 배경은 밖에서 얹는다
#Preview("번호 배지 + 연분홍 배경") {
    VStack(spacing: 0) {
        PlaceListRow(
            icon: .categoryFood,
            name: PlaceListRowPreview.name,
            address: PlaceListRowPreview.address,
            thumbnailURLs: PlaceListRowPreview.thumbnailURLs
        ) { url in
            RemoteImage(url: url)
        } trailing: {
            PlaceListRowPreviewMark(number: 1)
        }
        .background(PlaceListRowPreview.selectedBackground)

        PlaceListRow(
            icon: .categoryShopping,
            name: PlaceListRowPreview.name,
            address: PlaceListRowPreview.address
        ) {
            PlaceListRowPreviewMark(number: 2)
        }
        .background(PlaceListRowPreview.selectedBackground)

        PlaceListRow(
            icon: .categoryCafe,
            name: PlaceListRowPreview.name,
            address: PlaceListRowPreview.address
        ) {
            PlaceListRowPreviewMark(number: nil)
        }
    }
}

// a13: 검색 결과. 우측이 북마크 토글
#Preview("북마크 토글") {
    @Previewable @State var isBookmarked = false

    PlaceListRow(
        icon: .categoryFood,
        name: PlaceListRowPreview.name,
        address: PlaceListRowPreview.address,
        thumbnailURLs: PlaceListRowPreview.thumbnailURLs
    ) { url in
        RemoteImage(url: url)
    } trailing: {
        Button {
            isBookmarked.toggle()
        } label: {
            (isBookmarked ? Image.bookmarkFillColor : Image.bookmarkStroke)
                .resizable()
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }
}

// a13 · b04: 사진이 없으면 썸네일 줄 자체가 안 나온다
#Preview("썸네일 없는 행") {
    VStack(spacing: 0) {
        PlaceListRow(
            icon: .categoryCafe,
            name: PlaceListRowPreview.name,
            address: PlaceListRowPreview.address
        ) {
            Image.bookmarkStroke
                .resizable()
                .frame(width: 24, height: 24)
        }

        PlaceListRow(
            icon: .categoryTourism,
            name: "아주 긴 장소명이 들어오면 한 줄에서 잘린다 아주 긴 장소명",
            address: PlaceListRowPreview.address
        )
    }
}

// 우측 슬롯이 없으면 24 칸과 그 앞 여백이 사라져 장소명이 그만큼 더 나온다
#Preview("우측 슬롯 없는 행") {
    VStack(spacing: 0) {
        PlaceListRow(
            icon: .categoryTourism,
            name: "아주 긴 장소명이 들어오면 한 줄에서 잘린다 아주 긴 장소명",
            address: PlaceListRowPreview.address
        ) {
            PlaceListRowPreviewMark(number: nil)
        }

        PlaceListRow(
            icon: .categoryTourism,
            name: "아주 긴 장소명이 들어오면 한 줄에서 잘린다 아주 긴 장소명",
            address: PlaceListRowPreview.address
        )

        PlaceListRow(
            icon: .categoryFood,
            name: PlaceListRowPreview.name,
            address: PlaceListRowPreview.address,
            thumbnailURLs: PlaceListRowPreview.thumbnailURLs
        ) { url in
            RemoteImage(url: url)
        }
    }
}

#endif
