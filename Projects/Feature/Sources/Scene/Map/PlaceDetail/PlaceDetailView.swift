//
//  PlaceDetailView.swift
//  Dulpick
//

import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct PlaceDetailView: View {
    public let store: StoreOf<PlaceDetailFeature>

    /// 카카오맵을 여는 통로. 앱이 없으면 웹으로 보낸다
    @Environment(\.openURL) private var openURL

    /// 탭바 + 홈 인디케이터. `ignoresSafeArea` 안쪽이라 여기서 재면 0 이다
    private let bottomInset: CGFloat

    /// 시트 단계. 스토어에 묶으면 붙는 스프링이 도는 내내 리듀서가 돌아 화면이 다시 만들어진다
    @State private var detent: SheetDetent = .collapsed

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.s12, alignment: .top),
        GridItem(.flexible(), spacing: Spacing.s12, alignment: .top),
    ]

    public init(store: StoreOf<PlaceDetailFeature>, bottomInset: CGFloat) {
        self.store = store
        self.bottomInset = bottomInset
    }

    public var body: some View {
        MapBottomSheet(
            selection: $detent,
            expandLimit: .belowSearchBar
        ) {
            content
        }
        .onAppear { store.send(.onAppear) }
    }
}

// MARK: - 헤더

private extension PlaceDetailView {
    /// 잡이 막대만 고정이므로 본문 맨 위에 넣어 같이 스크롤한다. 시안 a06 의 위쪽이다
    var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(store.title)
                        .typography(.title3SB)
                        .foregroundStyle(Color.textPrimary)

                    subtitle
                }

                Spacer(minLength: Spacing.s8)

                bookmarkButton
                closeButton
            }
            .padding(.leading, Spacing.s20)
            .padding(.trailing, Spacing.s12)
            .padding(.vertical, PlaceDetailMetric.headerVerticalPadding)

            mapButton
        }
    }

    /// `장소 카테고리 · 저장한 사람 124` — 숫자만 강조색이다
    var subtitle: some View {
        HStack(spacing: 0) {
            Text("\(store.place.category.displayName) · 저장한 사람 ")
                .foregroundStyle(Color.textTertiary)
            Text("\(store.bookmarkCount)")
                .foregroundStyle(Color.brandPrimary)
        }
        .typography(.body2M)
    }

    var bookmarkButton: some View {
        headerIconButton(
            icon: store.isBookmarked ? Image.bookmarkFillColor : Image.bookmarkStroke
        ) {
            store.send(.bookmarkTapped)
        }
    }

    var closeButton: some View {
        headerIconButton(icon: Image.x) {
            store.send(.closeTapped)
        }
    }

    func headerIconButton(icon: Image, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon
                .resizable()
                .frame(width: 24, height: 24)
                .padding(8)
                .frame(
                    width: PlaceDetailMetric.headerActionSize,
                    height: PlaceDetailMetric.headerActionSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
    }

    var mapButton: some View {
        Button {
            if let appURL = store.kakaoMapAppURL {
                let webURL = store.kakaoMapWebURL
                openURL(appURL) { accepted in
                    guard !accepted, let webURL else { return }
                    openURL(webURL)
                }
            } else if let webURL = store.kakaoMapWebURL {
                openURL(webURL)
            }
        } label: {
            HStack(spacing: Spacing.s4) {
                Image.mappin
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                Text("지도")
                    .typography(.caption1M)
            }
            .foregroundStyle(store.canOpenKakaoMap ? Color.textSecondary : Color.textDisabled)
            .frame(width: PlaceDetailMetric.mapButtonWidth, height: 32)
            .background(Color.commonWhite)
            .overlay {
                RoundedRectangle(cornerRadius: PlaceDetailMetric.buttonCornerRadius)
                    .stroke(
                        store.canOpenKakaoMap ? Color.gray200 : Color.gray100,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(StaticButtonStyle())
        .disabled(!store.canOpenKakaoMap)
        .padding(.leading, Spacing.s20)
    }
}

// MARK: - 본문

private extension PlaceDetailView {
    /// 헤더와 주소는 항상 그린다. 사진 줄·게시물은 데이터가 있을 때만 붙는다
    var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if hasPhotos {
                PlacePhotoStrip(urls: store.place.thumbnailURLs)
                    .padding(.bottom, Spacing.s12)
            }

            addressRow
                .padding(.top, hasPhotos ? 0 : Spacing.s20)
                .padding(.bottom, Spacing.s16)

            if hasRelatedContents {
                relatedContents
                    .padding(.top, Spacing.s16)
            }
        }
        .padding(.bottom, Spacing.s32 + bottomInset)
    }

    /// 사진이 없는 장소는 사진 줄 자리를 통째로 비운다. 시안 a06·a07 이 그 장소의 화면이다
    var hasPhotos: Bool {
        !store.place.thumbnailURLs.isEmpty
    }

    var hasRelatedContents: Bool {
        !store.visibleContents.isEmpty
    }

    /// 시안 a07. 화살표를 누르면 `[지번] …` 이 한 줄 아래로 붙는다
    var addressRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Button { store.send(.addressToggled) } label: {
                HStack(alignment: .center, spacing: Spacing.s8) {
                    Image.mappin
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)

                    Text(store.place.roadAddress)
                        .typography(.body2M)
                        .multilineTextAlignment(.leading)

                    (store.isAddressExpanded ? Image.arrowUp : Image.arrowDown)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.vertical, Spacing.s4)
            }
            .buttonStyle(StaticButtonStyle())

            if store.isAddressExpanded {
                Text("[지번] \(store.place.address)")
                    .typography(.caption1R)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.leading, PlaceDetailMetric.jibunLeading)
            }
        }
        .padding(.horizontal, Spacing.s20)
    }

    var relatedContents: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("장소와 관련된 게시물")
                .typography(.headline)
                .foregroundStyle(Color.textPrimary)
                .padding(.bottom, Spacing.s16)

            LazyVGrid(columns: columns, spacing: Spacing.s20) {
                ForEach(store.visibleContents) { content in
                    Button { store.send(.contentTapped(content.id)) } label: {
                        RelatedContentCard(content: content)
                    }
                    .buttonStyle(StaticButtonStyle())
                }
            }

            if store.canLoadMore {
                moreButton
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.s20)
            }
        }
        .padding(.horizontal, Spacing.s20)
    }

    var moreButton: some View {
        Button { store.send(.moreTapped) } label: {
            Text("더보기")
                .typography(.caption1M)
                .foregroundStyle(Color.textSecondary)
                .frame(width: PlaceDetailMetric.moreButtonWidth, height: 32)
                .overlay {
                    RoundedRectangle(cornerRadius: PlaceDetailMetric.buttonCornerRadius)
                        .stroke(Color.gray200, lineWidth: 1)
                }
        }
        .buttonStyle(StaticButtonStyle())
    }
}

/// 시안 a06·a07 대조로 확정한 값. 토큰에 없는 것만 둔다
private enum PlaceDetailMetric {
    static let headerVerticalPadding: CGFloat = 5
    static let headerActionSize: CGFloat = 40
    static let buttonCornerRadius: CGFloat = 8
    static let mapButtonWidth: CGFloat = 75
    static let moreButtonWidth: CGFloat = 66
    static let jibunLeading: CGFloat = 28
}

/// `.plain` 은 누르는 동안 흐려져서, 시각 변화가 없는 스타일을 쓴다
private struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

#Preview("사진·게시물 있음") {
    PlaceDetailView(
        store: Store(
            initialState: PlaceDetailFeature.State(savedPlace: SavedPlace.mocks[0])
        ) {
            PlaceDetailFeature()
        },
        bottomInset: 0
    )
}

#Preview("사진·게시물 없음") {
    let source = Place.mocks.first { $0.thumbnailURLs.isEmpty } ?? Place.mocks[0]
    let place = Place(
        id: RelatedContentMock.emptyPlaceID,
        kakaoPlaceID: source.kakaoPlaceID,
        name: source.name,
        category: source.category,
        address: source.address,
        roadAddress: source.roadAddress,
        coordinate: source.coordinate,
        bookmarkCount: source.bookmarkCount,
        thumbnailURLs: source.thumbnailURLs
    )

    PlaceDetailView(
        store: Store(
            initialState: PlaceDetailFeature.State(
                savedPlace: SavedPlace(
                    place: place,
                    ownership: .mine,
                    alias: nil,
                    memo: nil,
                    savedAt: Date(timeIntervalSince1970: 1_786_000_000)
                )
            )
        ) {
            PlaceDetailFeature()
        },
        bottomInset: 0
    )
}
