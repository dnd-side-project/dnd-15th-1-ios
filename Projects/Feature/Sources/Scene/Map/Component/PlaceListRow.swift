import SharedDesignSystem
import SwiftUI

// MARK: - PlaceListRowMetric

private enum PlaceListRowMetric {
    static let iconSize: CGFloat = 24
    static let thumbnailSize: CGFloat = 88
    static let thumbnailCornerRadius: CGFloat = 12
    static let dividerHeight: CGFloat = 1
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
/// `Domain` 타입을 받지 않는다. 값만 받는다.
public struct PlaceListRow<Thumbnail: View, Trailing: View>: View {
    private let icon: Image
    private let name: String
    private let address: String
    private let thumbnailURLs: [URL]
    private let thumbnail: (URL) -> Thumbnail
    private let trailing: Trailing

    public init(
        icon: Image,
        name: String,
        address: String,
        thumbnailURLs: [URL] = [],
        @ViewBuilder thumbnail: @escaping (URL) -> Thumbnail,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.name = name
        self.address = address
        self.thumbnailURLs = thumbnailURLs
        self.thumbnail = thumbnail
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            header

            if !thumbnailURLs.isEmpty {
                thumbnails
            }
        }
        .padding(.vertical, Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { divider }
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

            Spacer(minLength: Spacing.s12)

            // 아이콘과 같은 높이를 확보해 장소명 줄에 맞춘다. 슬롯은 24 × 24 로 고정이다.
            trailing
                .frame(
                    width: PlaceListRowMetric.iconSize,
                    height: PlaceListRowMetric.iconSize
                )
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

public extension PlaceListRow where Thumbnail == EmptyView {
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
        ) {
            EmptyView()
        }
    }
}
