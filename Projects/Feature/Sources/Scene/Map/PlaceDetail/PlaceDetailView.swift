//
//  PlaceDetailView.swift
//  Dulpick
//

import ComposableArchitecture
import CoreUserAnalytics
import Domain
import SharedDesignSystem
import SharedUtils
import SwiftUI
import ThirdParty

public struct PlaceDetailView: View {
    public let store: StoreOf<PlaceDetailFeature>

    /// 지도 앱을 여는 통로. 앱이 없으면 그 지도의 웹으로 보낸다
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
        .bottomSheet(isPresented: mapSheetBinding) {
            mapSheet
        }
        .fullScreenCover(isPresented: photoViewerBinding) {
            photoViewer
        }
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
                        .analyticsMasked(store.alias != nil)

                    subtitle
                }
                // 시안 「text area」 만 위아래 5 를 둔다. 닫기 버튼은 줄 맨 위에 붙는다
                .padding(.vertical, PlaceDetailMetric.headerVerticalPadding)

                Spacer(minLength: Spacing.s8)

                closeButton
            }

            HStack(spacing: 0) {
                bookmarkButton
                Spacer(minLength: Spacing.s8)
                mapButton
            }
        }
        .padding(.leading, Spacing.s20)
        .padding(.trailing, Spacing.s12)
    }

    /// `둘픽 분류 · 세부 분류 · 저장한 사람 124` — 숫자만 강조색이다. 저장 수를 모르면 그 조각이 빠진다.
    /// 한 줄을 넘으면 「저장한 사람 N」 을 다음 줄로 내리고, 첫 줄도 넘치면 세부 분류 끝을 말줄임한다
    var subtitle: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                categoryLine
                if let bookmarkCount = store.bookmarkCount {
                    Text(" · ")
                        .foregroundStyle(Color.textTertiary)
                    bookmarkLine(bookmarkCount)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                categoryLine
                if let bookmarkCount = store.bookmarkCount {
                    bookmarkLine(bookmarkCount)
                }
            }
        }
        .typography(.body2M)
    }

    /// 「둘픽 분류 · 세부 분류」. 넘치면 세부 분류 끝만 말줄임한다
    var categoryLine: some View {
        HStack(spacing: 0) {
            Text(store.place.category.displayName)
                .fixedSize()
            if let detail = store.detailCategoryText {
                Text(" · \(detail)")
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .foregroundStyle(Color.textTertiary)
    }

    /// 「저장한 사람 N」. 글자와 숫자가 갈라지지 않게 한 덩어리로 둔다
    func bookmarkLine(_ count: Int) -> some View {
        HStack(spacing: 0) {
            Text("저장한 사람 ")
                .foregroundStyle(Color.textTertiary)
            Text("\(count)")
                .foregroundStyle(Color.brandPrimary)
        }
        .fixedSize()
    }

    /// 저장 전에는 빈 아이콘을 회색으로 칠하고, 저장 뒤에는 분홍 채움 아이콘을 원래 색으로 쓴다
    /// 지도로 보기와 함께 `Button` 대신 탭 제스처를 쓴다. `Button` 은 시트를 끌어 올린 뒤 손을 떼도 눌린다
    var bookmarkButton: some View {
        HStack(spacing: Spacing.s4) {
            Group {
                if store.isBookmarked {
                    Image.bookmarkFilled
                        .resizable()
                } else {
                    Image.bookmarkEmpty
                        .renderingMode(.template)
                        .resizable()
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .frame(width: 16, height: 16)

            Text("저장")
                .typography(.caption1M)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, Spacing.s16)
        .frame(height: 32)
        .background(Color.commonWhite)
        .overlay {
            RoundedRectangle(cornerRadius: PlaceDetailMetric.buttonCornerRadius)
                .stroke(Color.gray200, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { store.send(.bookmarkTapped) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    var closeButton: some View {
        headerIconButton(icon: Image.x) {
            store.send(.closeTapped)
        }
    }

    /// 저장·지도로 보기와 같은 까닭으로 `Button` 대신 탭 제스처를 쓴다
    func headerIconButton(icon: Image, action: @escaping () -> Void) -> some View {
        icon
            .renderingMode(.template)
            .resizable()
            .frame(width: 24, height: 24)
            .foregroundStyle(Color.textTertiary)
            .padding(8)
            .frame(
                width: PlaceDetailMetric.headerActionSize,
                height: PlaceDetailMetric.headerActionSize
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
    }

    var mapButton: some View {
        HStack(spacing: Spacing.s4) {
            Image.map
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.gray50)
            Text("지도로 보기")
                .typography(.caption1M)
                .foregroundStyle(Color.commonWhite)
        }
        .padding(.horizontal, Spacing.s16)
        .frame(height: 32)
        .background(
            Color.gray900,
            in: RoundedRectangle(cornerRadius: PlaceDetailMetric.buttonCornerRadius)
        )
        .contentShape(RoundedRectangle(cornerRadius: PlaceDetailMetric.buttonCornerRadius))
        .onTapGesture { store.send(.mapButtonTapped) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - 지도 시트

private extension PlaceDetailView {
    /// 바깥을 눌러 닫으면 `false` 가 들어온다. 줄을 고르면 리듀서가 닫는다
    var mapSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isMapSheetPresented },
            set: { isPresented in
                if !isPresented { store.send(.mapSheetDismissed) }
            }
        )
    }

    var mapSheet: some View {
        PlaceMapSheet(
            title: store.title,
            isAlias: store.alias != nil,
            onSelect: { openMap($0) },
            onClose: { store.send(.mapSheetDismissed) }
        )
        // 장소 상세 층이 아래 안전 영역을 지워서, 시트가 홈 표시줄을 스스로 비키지 못한다
        .padding(.bottom, bottomInset)
    }

    /// 시트를 닫고 고른 지도 앱을 연다. 앱이 없어 열기가 실패하면 같은 지도의 웹을 연다
    func openMap(_ app: PlaceMapApp) {
        let link = store.state.mapLink(for: app, bundleID: AppInfo.bundleID)
        store.send(.mapAppTapped(app))
        guard let link else { return }
        openURL(link.appURL) { accepted in
            guard !accepted else { return }
            openURL(link.webURL)
        }
    }
}

// MARK: - 사진 뷰어

private extension PlaceDetailView {
    var photoViewerBinding: Binding<Bool> {
        Binding(
            get: { store.photoViewer != nil },
            set: { isPresented in
                if !isPresented { store.send(.photoViewerDismissed) }
            }
        )
    }

    @ViewBuilder
    var photoViewer: some View {
        if let viewer = store.photoViewer {
            PlacePhotoViewer(
                urls: viewer.urls,
                initialIndex: viewer.currentIndex,
                title: store.place.name,
                onPageChanged: { store.send(.photoViewerPageChanged($0)) },
                onClose: { sendWithoutAnimation(.photoViewerDismissed) }
            )
            .ignoresSafeArea()
            .presentationBackground(.clear)
            // 시안은 검은 배경 위 흰 상태 표시줄이다. 상태 표시줄은 덮개가 정하고 UIKit 쪽 스타일은 묻지 않는다.
            // 이 모드는 이 덮개에만 걸리고, 닫히면 원래대로 돌아온다
            .preferredColorScheme(.dark)
        }
    }

    /// 사진 뷰어는 스스로 흐려지며 열리고 닫힌다. 전체 화면 덮개의 밀어 올리기를 끈다
    func sendWithoutAnimation(_ action: PlaceDetailFeature.Action) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        store.send(action, transaction: transaction)
    }
}

// MARK: - 본문

private extension PlaceDetailView {
    /// 헤더와 주소는 항상 그린다. 사진 줄·게시물은 데이터가 있을 때만 붙는다
    var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if hasPhotos {
                PlacePhotoStrip(
                    urls: store.place.thumbnailURLs,
                    onTap: { sendWithoutAnimation(.photoTapped($0)) }
                )
                    .padding(.bottom, Spacing.s12)
            }

            addressRow
                .padding(.top, hasPhotos ? 0 : Spacing.s20)
                .padding(.bottom, Spacing.s16)

            if showsRelatedSection {
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

    /// 서버 ID 가 없으면 부를 수가 없다. 다 부르고 0건이면 지금처럼 통째로 숨긴다
    var showsRelatedSection: Bool {
        guard store.serverPlaceID != nil else { return false }
        if !store.contents.isEmpty { return true }
        switch store.contentsLoadState {
        case .loading, .failed:
            return true
        case .loaded:
            return false
        }
    }

    /// 시안 a07. 화살표를 누르면 `[지번] …` 이 한 줄 아래로 붙는다
    var addressRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            // 저장·지도로 보기와 같은 까닭으로 `Button` 대신 탭 제스처를 쓴다
            HStack(alignment: .center, spacing: Spacing.s8) {
                Image.mapPin
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)

                Text(store.place.roadAddress ?? "")
                    .typography(.body2M)
                    .multilineTextAlignment(.leading)

                (store.isAddressExpanded ? Image.chevronUp : Image.chevronDown)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            .foregroundStyle(Color.textSecondary)
            .padding(.vertical, Spacing.s4)
            .contentShape(Rectangle())
            .onTapGesture { store.send(.addressToggled) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)

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

            if store.contents.isEmpty {
                switch store.contentsLoadState {
                case .loading:
                    contentsSkeleton
                case .failed:
                    contentsFailure
                case .loaded:
                    contentsGrid
                }
            } else {
                contentsGrid
            }
        }
        .padding(.horizontal, Spacing.s20)
    }

    var contentsGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            LazyVGrid(columns: columns, spacing: Spacing.s20) {
                ForEach(store.contents) { content in
                    Button { store.send(.contentTapped(content.id)) } label: {
                        RelatedContentCard(content: content)
                    }
                    .buttonStyle(StaticButtonStyle())
                }
            }

            if store.hasNextContents {
                moreButton
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.s20)
                    .disabled(store.contentsLoadState == .loading)
                    .opacity(store.contentsLoadState == .loading ? 0.4 : 1)
            }
        }
    }

    /// 첫 장을 기다리는 자리. 카드 네 개 자리를 그대로 채운다
    var contentsSkeleton: some View {
        LazyVGrid(columns: columns, spacing: Spacing.s20) {
            ForEach(0..<PlaceDetailFeature.contentPageSize, id: \.self) { _ in
                ShimmerBlock(cornerRadius: PlaceDetailMetric.buttonCornerRadius, baseColor: .gray300)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
            }
        }
    }

    var contentsFailure: some View {
        VStack(spacing: Spacing.s16) {
            EmptyStateView(
                image: .emptyResult,
                title: "게시물을 불러오지 못했어요",
                message: "잠시 뒤 다시 시도해주세요"
            )

            AppButton("다시 시도", style: .outlined, size: .md) {
                store.send(.retryContentsTapped)
            }
        }
        .frame(maxWidth: .infinity)
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
        placeID: source.placeID,
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
        } withDependencies: {
            $0.contentClient.placeContents = { _, _, _ in ContentPage(items: [], hasNext: false) }
        },
        bottomInset: 0
    )
}
