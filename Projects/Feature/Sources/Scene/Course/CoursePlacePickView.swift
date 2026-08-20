import ComposableArchitecture
import Domain
import SharedDesignSystem
import SwiftUI

// MARK: - CoursePlacePickMetric

private enum CoursePlacePickMetric {
    static let cornerRadius: CGFloat = 12
    static let skeletonRowCount = 3
    static let skeletonRowHeight: CGFloat = 64
    static let backButtonSize: CGFloat = 44
    static let backButtonIconSide: CGFloat = 24
    static let ctaButtonHeight: CGFloat = 56
    /// 목록 마지막 행과 CTA 버튼 윗면 사이
    static let listGapAboveCTA: CGFloat = 20
}

// MARK: - CoursePlacePickView

/// 코스에 담을 장소를 고르는 화면. 시안 b04 · b05 · b06 · b07.
///
/// 고른 순서가 곧 번호다.
public struct CoursePlacePickView: View {
    @Bindable private var store: StoreOf<CourseFeature>
    @Environment(\.dismiss) private var dismiss

    /// 시트 단계. 시트가 접혀 있는지 펼쳐져 있는지다
    @State private var sheetDetent: SheetDetent = .collapsed

    @State private var bottomInset: CGFloat = 0

    /// 지금 열린 필터 메뉴. 하나만 열린다
    @State private var openFilterMenu: FilterMenu?
    @State private var ownershipMenuFrame: CGRect?
    @State private var categoryMenuFrame: CGRect?

    public init(store: StoreOf<CourseFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            bottomInsetProbe
            ZStack(alignment: .bottom) {
                map
                backButtonLayer
                sheet
                cta
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        // 네비바가 있으면 안전영역이 늘어 시트가 그만큼 내려앉는다
        .toolbar(.hidden, for: .navigationBar)
        .task { store.send(.onAppear) }
    }
}

// MARK: - Layer

private extension CoursePlacePickView {

    var bottomInsetProbe: some View {
        GeometryReader { _ in
            Color.clear
                .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: {
                    bottomInset = $0
                }
        }
        .allowsHitTesting(false)
    }

    /// 마지막 행이 CTA 버튼 윗면에서 20 위에 서게 시트가 그만큼 더 올라간다.
    /// 그라데이션은 안 피한다. 그 아래로 목록이 비쳐 보이는 것이 그 층의 뜻이다
    var ctaCoverPadding: CGFloat {
        Spacing.s20                                 // CTAContainer 의 버튼 아래 패딩
            + CoursePlacePickMetric.ctaButtonHeight
            + CoursePlacePickMetric.listGapAboveCTA
            + bottomInset
    }

    var map: some View {
        DulpickMapView(
            camera: Binding(
                get: { store.camera },
                set: { store.send(.cameraChanged($0)) }
            ),
            markers: store.markers,
            onMarkerTap: { store.send(.markerTapped($0)) }
        )
        .ignoresSafeArea()
    }

    /// 뒤로가기가 서치바 자리에 선다. 시트 펼침 한계가 그 자리를 기준으로 잡혀 있다
    var backButtonLayer: some View {
        backButton
            .padding(.horizontal, Spacing.s20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var sheet: some View {
        MapBottomSheet(
            selection: $sheetDetent,
            // 이 화면엔 서치바가 없다. 뒤로가기 버튼이 같은 높이에 있어 그 아래 8 에서 멈춘다
            expandLimit: .belowSearchBar,
            openMenuFrames: [ownershipMenuFrame, categoryMenuFrame].compactMap { $0 },
            // 끌기 시작하면 열린 메뉴를 닫는다. 열어둔 채 끌면 메뉴가 시트를 따라다녀 어색하다
            onDragBegan: { openFilterMenu = nil }
        ) {
            EmptyView()
        } header: {
            sheetHeader
        } content: {
            sheetContent
        }
    }

    /// 화면 아래에 고정된 CTA. 시트를 올려도 화면에서 자리가 안 바뀐다 (b04 · b06 · b07)
    var cta: some View {
        CTAContainer {
            AppButton(store.ctaTitle, style: .dark, size: .xl, fullWidth: true) {
                store.send(.buildTapped)
            }
            .disabled(!store.isCTAEnabled)
        }
    }

    var sheetHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Text("저장한 장소")
                .typography(.title3SB)
                .foregroundStyle(Color.textPrimary)

            HStack(spacing: Spacing.s8) {
                if store.isCoupleConnected {
                    AppDropdown(
                        selection: ownershipBinding,
                        isExpanded: filterMenuBinding(.ownership),
                        placeholder: PlaceOwnership.together.displayName,
                        options: PlaceOwnership.mapDisplayOrder.map(\.displayName),
                        onMenuFrameChange: { ownershipMenuFrame = $0 }
                    )
                }

                AppDropdown(
                    selection: categoryBinding,
                    isExpanded: filterMenuBinding(.category),
                    placeholder: PlaceCategory.unfilteredName,
                    options: [PlaceCategory.unfilteredName] + PlaceCategory.mapDisplayOrder.map(\.displayName),
                    onMenuFrameChange: { categoryMenuFrame = $0 }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.s20)
        .padding(.bottom, Spacing.s8)
    }

    @ViewBuilder
    var sheetContent: some View {
        switch store.loadState {
        case .loading:
            skeleton
        case .failed:
            failureState
        case .loaded:
            if store.isEmpty {
                emptyState
            } else {
                placeList
            }
        }
    }

    var placeList: some View {
        VStack(spacing: 0) {
            ForEach(store.filteredPlaces) { saved in
                row(saved, showsDivider: saved.id != store.filteredPlaces.last?.id)
            }
        }
        .padding(.top, Spacing.s8)
        .padding(.bottom, ctaCoverPadding)
    }

    func row(_ saved: SavedPlace, showsDivider: Bool) -> some View {
        let badge = store.state.badgeState(for: saved.id)

        return PlaceListRow(
            icon: saved.place.category.icon,
            name: saved.alias ?? saved.place.name,
            address: saved.place.address,
            showsDivider: showsDivider,
            thumbnailURLs: saved.place.thumbnailURLs
        ) { url in
            RemoteImage(url: url, cornerRadius: CoursePlacePickMetric.cornerRadius)
        } trailing: {
            PlaceNumberBadge(state: badge)
        }
        // 배경은 행이 안 칠한다. 고른 행만 여기서 연분홍을 얹는다 (b06)
        .background(badge == .unselected ? Color.clear : Color.brandSurface)
        .contentShape(Rectangle())
        .onTapGesture { store.send(.rowTapped(saved.id)) }
    }

    var skeleton: some View {
        VStack(spacing: Spacing.s16) {
            ForEach(0 ..< CoursePlacePickMetric.skeletonRowCount, id: \.self) { _ in
                ShimmerBlock(cornerRadius: CoursePlacePickMetric.cornerRadius)
                    .frame(height: CoursePlacePickMetric.skeletonRowHeight)
            }
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.top, Spacing.s8)
    }

    var failureState: some View {
        VStack(spacing: Spacing.s16) {
            EmptyStateView(
                image: .placeEmpty,
                title: "장소를 불러오지 못했어요",
                message: "잠시 뒤 다시 시도해주세요"
            )

            AppButton("다시 시도", style: .outlined, size: .md) {
                store.send(.retryTapped)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.s32)
        .padding(.bottom, ctaCoverPadding)
    }

    var emptyState: some View {
        EmptyStateView(
            image: .placeEmpty,
            title: store.hasNoSavedPlace ? "저장한 장소가 없어요" : "조건에 맞는 장소가 없어요",
            message: store.hasNoSavedPlace ? "마음에 드는 장소를 저장해보세요" : "필터를 바꿔보세요"
        )
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.s32)
        .padding(.bottom, ctaCoverPadding)
    }

    var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image.arrowLeft
                .renderingMode(.template)
                .resizable()
                .frame(
                    width: CoursePlacePickMetric.backButtonIconSide,
                    height: CoursePlacePickMetric.backButtonIconSide
                )
                .foregroundStyle(Color.textSecondary)
                .frame(
                    width: CoursePlacePickMetric.backButtonSize,
                    height: CoursePlacePickMetric.backButtonSize
                )
                .glassCircleBackground()
        }
        .buttonStyle(.plain)
    }

    /// 메뉴 하나의 열림 바인딩. 하나를 열면 다른 하나가 저절로 닫힌다
    func filterMenuBinding(_ menu: FilterMenu) -> Binding<Bool> {
        Binding(
            get: { openFilterMenu == menu },
            set: { isOpen in openFilterMenu = isOpen ? menu : nil }
        )
    }

    var ownershipBinding: Binding<String?> {
        Binding(
            get: { store.selectedOwnership == .together ? nil : store.selectedOwnership.displayName },
            set: { newValue in
                guard let newValue else {
                    store.send(.ownershipSelected(.together))
                    return
                }
                guard let filter = PlaceOwnership.fromDisplayName(newValue) else { return }
                store.send(.ownershipSelected(filter))
            }
        )
    }

    var categoryBinding: Binding<String?> {
        Binding(
            get: { store.selectedCategory?.displayName },
            set: { newValue in
                guard let newValue, newValue != PlaceCategory.unfilteredName else {
                    store.send(.categoryTapped(nil))
                    return
                }
                guard let category = PlaceCategory.fromDisplayName(newValue) else { return }
                // 리듀서가 같은 값 재탭을 해제로 읽는다. 드롭다운은 늘 그 값으로 놓아야 한다
                if store.selectedCategory != category {
                    store.send(.categoryTapped(category))
                }
            }
        )
    }
}
