import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

// MARK: - RowMenuOption

/// 장소 행의 `⋮` 메뉴 항목. 글자와 액션을 한자리에 묶어 `else` 로 삭제가 도는 걸 막는다.
private enum RowMenuOption: String, CaseIterable {
    case edit = "수정"
    case delete = "삭제"
}

// MARK: - MapView

public struct MapView: View {
    @Bindable public var store: StoreOf<MapFeature>

    /// 시트 단계. 시트가 접혀 있는지 펼쳐져 있는지다
    @State private var sheetDetent: SheetDetent = .collapsed

    /// 아래 안전영역(탭바 + 홈 인디케이터). 시트가 그 뒤로 이어지므로 목록 아래 여백에 더한다
    @State private var bottomInset: CGFloat = 0

    /// 접힘 시트 윗면의 화면 좌표 y. 지도가 초점 자리를 잡는 근거다
    @State private var collapsedSheetTop: CGFloat = 0

    /// 지금 열린 필터 메뉴. 하나만 열린다
    @State private var openFilterMenu: FilterMenu?

    /// 저장자 드롭다운 메뉴의 화면 좌표. 시트 손짓이 이 안에서는 시작하지 않는다
    @State private var ownershipMenuFrame: CGRect?

    /// 카테고리 드롭다운 메뉴의 화면 좌표. 한쪽이 닫혀도 다른 쪽 자리를 지우지 않으려고 따로 둔다
    @State private var categoryMenuFrame: CGRect?

    /// 행 `⋮` 메뉴의 화면 좌표와 그 주인 행. 한 번에 하나만 열린다.
    /// 주인을 같이 드는 이유는, 다른 행을 열 때 옛 행의 사라짐이 새 좌표를 지우지 못하게 하려는 것이다
    @State private var rowMenu: (id: String, frame: CGRect)?

    public init(store: StoreOf<MapFeature>) {
        self.store = store
    }

    public var body: some View {
        // 두 값은 조건이 달라 재는 층을 나눈다. 아래 안전영역은 안전영역을 무시하지 않는
        // 자리에서만 실제 값이 나오므로, 그 층만 아래 뭉치 밖에 형제로 세운다
        ZStack {
            bottomInsetProbe
            mapLayers
        }
    }
}

// MARK: - 층 나누기

private extension MapView {
    /// 지도 · 칩 · 시트 · 검색바 뭉치. 아래 안전영역을 무시하는 쪽이다
    var mapLayers: some View {
        // 세 층의 순서가 곧 시안이다. 칩 줄도 검색바도 시트에 덮인다.
        // 펼침이 안전영역 위 끝까지 오르므로 검색바가 시트 아래로 들어가야 한다
        ZStack(alignment: .bottom) {
            map
            categoryChipLayer
            searchBarLayer
            sheetSwap
        }
        // 시트 흰 배경이 탭바 뒤로 이어지는 근거다. 빼면 시트 아래로 지도가 비친다
        .ignoresSafeArea(edges: .bottom)
        .toolbar(.hidden, for: .navigationBar)
        .toast(item: toastBinding) { store.send(.retryTapped) }
        .onAppear { store.send(.onAppear) }
    }

    /// 상세가 뜨면 목록을 치운다. 접힘 위에 목록이 남으면 시안 a06·a07 과 어긋난다.
    /// 상세 시트는 `MapFlowView` 가 같은 스프링으로 얹는다.
    /// 껍데기에 숨김 단계가 없어(`SheetDetent` 가 접힘·펼침 둘뿐) 시트를 통째로 갈아
    /// 내려갔다 올라오게 만든다. 스프링은 껍데기의 `MapBottomSheetMetric.settle` 이다.
    @ViewBuilder
    var sheetSwap: some View {
        ZStack(alignment: .bottom) {
            if store.selectedPlace == nil {
                sheet
                    // 올라오며 나타나고, 사라질 때는 안 움직인다. 안 주면 기본값인 페이드가 붙는다
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .identity))
            }
        }
        .animation(
            MapBottomSheetMetric.settle,
            value: store.selectedPlace == nil
        )
    }

    /// 아래 안전영역(탭바 + 홈 인디케이터)을 재는 층.
    /// `ignoresSafeArea` 안쪽에서 물으면 안전영역이 이미 먹혀 0 이 오므로, 아무 것도 걸지 않는다
    var bottomInsetProbe: some View {
        GeometryReader { proxy in
            Color.clear
                .onGeometryChange(for: CGFloat.self) { _ in proxy.safeAreaInsets.bottom } action: {
                    bottomInset = $0
                }
        }
        // Color.clear 도 탭을 받는다. 지도보다 아래층이지만 확실히 비켜둔다
        .allowsHitTesting(false)
    }
}

// MARK: - 지도

private extension MapView {
    var map: some View {
        DulpickMapView(
            camera: Binding(
                get: { store.camera },
                set: { store.send(.cameraChanged($0)) }
            ),
            markers: store.markers,
            onMarkerTap: { store.send(.markerTapped($0)) },
            onMapTap: { store.send(.rowMenuDismissed) },
            collapsedSheetTop: collapsedSheetTop
        )
        .ignoresSafeArea()
    }
}

// MARK: - 상단 검색바 · 카테고리 칩

private extension MapView {
    @ViewBuilder
    var categoryChipLayer: some View {
        if !store.isSearching {
            savedChipLayer
        }
    }

    /// 시트 아래층. 시트가 올라오면 덮인다
    var savedChipLayer: some View {
        CategoryChipBar(
            items: chipItems,
            selection: store.selectedCategory
        ) { category in
            store.send(.categoryTapped(category))
        }
        // 검색바와 따로 걸어도 결과가 같다. 묶음 그림자도 투명도를 따라 부품마다 그려진다
        .shadow(
            color: Color.commonBlack.opacity(MapViewMetric.topControlsShadowOpacity),
            radius: MapViewMetric.topControlsShadowRadius,
            y: MapViewMetric.topControlsShadowOffsetY
        )
        .padding(.top, MapViewMetric.searchBarBottom + Spacing.s8)
        // 화면 높이를 채우기 전에 걸어야 그림자가 투명 영역까지 번지지 않는다
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// 시트 아래층. 시트를 펼치면 덮인다
    var searchBarLayer: some View {
        MapSearchBar(
            placeholder: "원하는 장소를 검색하세요",
            text: store.searchQuery,
            onTap: { store.send(.searchBarTapped) },
            onClear: { store.send(.searchClearTapped) },
            onBack: store.isSearching ? { store.send(.searchBackTapped) } : nil
        )
        .padding(.horizontal, Spacing.s20)
        .shadow(
            color: Color.commonBlack.opacity(MapViewMetric.topControlsShadowOpacity),
            radius: MapViewMetric.topControlsShadowRadius,
            y: MapViewMetric.topControlsShadowOffsetY
        )
        .frame(maxHeight: .infinity, alignment: .top)
    }

    var chipItems: [CategoryChipItem<PlaceCategory>] {
        PlaceCategory.mapDisplayOrder.map { category in
            CategoryChipItem(
                id: category,
                icon: category.icon,
                title: category.displayName
            )
        }
    }
}

// MARK: - 떠 있는 버튼

private extension MapView {
    var floatingControls: some View {
        HStack(spacing: Spacing.s12) {
            if !store.isSearching {
                MapFloatingButton(title: "데이트 코스 짜러가기") {
                    store.send(.courseButtonTapped)
                }
            }

            Spacer(minLength: Spacing.s12)

            MapFloatingButton(icon: .locate) {
                store.send(.currentLocationTapped)
            }
        }
        .padding(.horizontal, Spacing.s20)
    }
}

// MARK: - 시트

private extension MapView {
    var sheet: some View {
        MapBottomSheet(
            selection: $sheetDetent,
            expandLimit: store.isSearching ? .belowSearchBar : .safeAreaTop,
            openMenuFrames: [ownershipMenuFrame, categoryMenuFrame, rowMenu?.frame].compactMap { $0 },
            // 끌기 시작하면 열린 메뉴를 닫는다. 열어둔 채 끌면 메뉴가 시트를 따라다녀 어색하다
            onDragBegan: {
                openFilterMenu = nil
                store.send(.rowMenuDismissed)
            },
            gestureKind: .a,
            onCollapsedTopChange: { collapsedSheetTop = $0 },
        ) {
            floatingControls
        } header: {
            sheetHeader
        } content: {
            sheetContent
        }
    }

    @ViewBuilder
    var sheetHeader: some View {
        if store.isSearching {
            EmptyView()
        } else {
            savedSheetHeader
        }
    }

    var savedSheetHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Text("저장한 장소")
                .typography(.title3SB)
                .foregroundStyle(Color.textPrimary)

            HStack(spacing: Spacing.s8) {
                // 커플이 연동되어야 나온다. 미연동이면 카테고리 칩만 남는다
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
        if store.isSearching {
            searchResultList
        } else {
            savedSheetContent
        }
    }

    @ViewBuilder
    var savedSheetContent: some View {
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

    /// 검색 결과 행. 사진을 안 넘기고 우측에 북마크를 둔다
    var searchResultList: some View {
        VStack(spacing: 0) {
            ForEach(store.searchResults) { place in
                PlaceListRow(
                    icon: place.category.icon,
                    name: place.name,
                    address: place.address,
                    showsDivider: place.id != store.searchResults.last?.id
                ) {
                    bookmarkButton(place.id)
                }
                .contentShape(Rectangle())
                .onTapGesture { store.send(.rowTapped(place.id)) }
            }
        }
        .padding(.top, Spacing.s8)
        .padding(.bottom, Spacing.s20 + bottomInset)
    }

    func bookmarkButton(_ id: String) -> some View {
        Button {
            store.send(.bookmarkTapped(id))
        } label: {
            (store.bookmarkedPlaceIDs.contains(id) ? Image.bookmarkFillColor : Image.bookmarkStroke)
                .resizable()
                .frame(
                    width: MapViewMetric.menuIconSize,
                    height: MapViewMetric.menuIconSize
                )
        }
        .buttonStyle(.plain)
    }

    /// 알림 띠는 3초 뒤 스스로 사라진다. 띠만 믿으면 재시도할 길이 없어져 본문에도 길을 둔다
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
    }

    var skeleton: some View {
        VStack(spacing: Spacing.s16) {
            ForEach(0 ..< MapViewMetric.skeletonRowCount, id: \.self) { _ in
                ShimmerBlock(cornerRadius: MapViewMetric.cornerRadius)
                    .frame(height: MapViewMetric.skeletonRowHeight)
            }
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.top, Spacing.s8)
    }

    var emptyState: some View {
        EmptyStateView(
            image: .placeEmpty,
            title: store.hasNoSavedPlace ? "저장한 장소가 없어요" : "조건에 맞는 장소가 없어요",
            message: store.hasNoSavedPlace ? "마음에 드는 장소를 저장해보세요" : "필터를 바꿔보세요"
        )
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.s32)
    }

    var placeList: some View {
        VStack(spacing: 0) {
            ForEach(store.filteredPlaces) { saved in
                row(saved, showsDivider: saved.id != store.filteredPlaces.last?.id)
                    // 팝오버는 행 밖으로 나간다. 열린 행을 올려야 아래 행에 덮이지 않는다
                    .zIndex(store.menuTargetPlaceID == saved.id ? 1 : 0)
            }
        }
        .padding(.top, Spacing.s8)
        // 마지막 행이 탭바에 가리지 않게 시트가 그만큼 더 올라간다
        .padding(.bottom, Spacing.s20 + bottomInset)
    }

    func row(_ saved: SavedPlace, showsDivider: Bool) -> some View {
        PlaceListRow(
            icon: saved.place.category.icon,
            name: saved.alias ?? saved.place.name,
            address: saved.place.address,
            showsDivider: showsDivider,
            thumbnailURLs: saved.place.thumbnailURLs
        ) { url in
            RemoteImage(url: url, cornerRadius: MapViewMetric.cornerRadius)
        } trailing: {
            menuButton(saved.id)
        }
        .contentShape(Rectangle())
        .onTapGesture { store.send(.rowTapped(saved.id)) }
    }

    func menuButton(_ id: String) -> some View {
        Button {
            store.send(.rowMenuTapped(id))
        } label: {
            Image.menu
                .renderingMode(.template)
                .resizable()
                .frame(
                    width: MapViewMetric.menuIconSize,
                    height: MapViewMetric.menuIconSize
                )
                .foregroundStyle(Color.textTertiary)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if store.menuTargetPlaceID == id {
                DropdownMenu(options: RowMenuOption.allCases.map(\.rawValue), style: .menu) { option in
                    switch RowMenuOption(rawValue: option) {
                    case .edit:
                        store.send(.editTapped(id))
                    case .delete:
                        store.send(.deleteTapped(id))
                    case nil:
                        break
                    }
                }
                .fixedSize()
                // 아래 .offset 까지 반영된 자리가 나온다. 손으로 더하면 그만큼 아래로 밀린다
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    rowMenu = (id, frame)
                }
                .offset(y: MapViewMetric.rowMenuOffsetY)
                .onDisappear {
                    // 다른 행을 여는 순간에는 새 행이 이미 주인이다. 그때는 지우지 않는다
                    if rowMenu?.id == id {
                        rowMenu = nil
                    }
                }
            }
        }
    }
}

// MARK: - Binding

private extension MapView {
    /// 메뉴 하나의 열림 바인딩. 하나를 열면 다른 하나가 저절로 닫힌다
    func filterMenuBinding(_ menu: FilterMenu) -> Binding<Bool> {
        Binding(
            get: { openFilterMenu == menu },
            set: { isOpen in openFilterMenu = isOpen ? menu : nil }
        )
    }

    /// `AppDropdown` 은 문자열만 오간다. 값으로 되돌려 액션에 싣는다
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

    var toastBinding: Binding<ToastState?> {
        Binding(
            get: { store.toast },
            set: { newValue in
                if newValue == nil {
                    store.send(.dismissToast)
                }
            }
        )
    }
}

// MARK: - MapViewMetric

private enum MapViewMetric {
    static let skeletonRowCount = 3
    static let skeletonRowHeight: CGFloat = 64
    static let cornerRadius: CGFloat = 12
    static let menuIconSize: CGFloat = 24

    /// `⋮` 버튼 아래에 팝오버가 붙는 거리. 버튼 높이만큼 내린다
    static let rowMenuOffsetY: CGFloat = 32

    static let topControlsShadowRadius: CGFloat = 4
    static let topControlsShadowOpacity: Double = 0.10
    static let topControlsShadowOffsetY: CGFloat = 2

    /// 안전영역 상단에서 검색바 바닥까지
    static let searchBarBottom: CGFloat = 48
}

#if DEBUG
// a08 · a09 — 커플 연동, 저장한 장소가 있는 기본 상태
#Preview("기본") {
    KakaoMapPreviewContainer {
        MapView(
            store: Store(initialState: MapFeature.State()) {
                MapFeature()
            } withDependencies: {
                $0.placeClient = .mock
                $0.coupleClient.current = {
                    CoupleStatus(
                        connected: true,
                        me: CoupleMember(nickname: "나", iconID: 1),
                        partner: CoupleMember(nickname: "둘", iconID: 1),
                        daysTogether: nil
                    )
                }
            }
        )
    }
}

// 커플 미연동 — 저장자 칩이 사라진다
#Preview("미연동") {
    KakaoMapPreviewContainer {
        MapView(
            store: Store(initialState: MapFeature.State()) {
                MapFeature()
            } withDependencies: {
                $0.placeClient = .mock
                $0.coupleClient.current = { nil }
            }
        )
    }
}

// 저장한 장소가 없는 빈 상태
#Preview("빈 상태") {
    KakaoMapPreviewContainer {
        MapView(
            store: Store(initialState: MapFeature.State()) {
                MapFeature()
            } withDependencies: {
                $0.placeClient.savedPlaces = { [] }
                $0.coupleClient.current = { nil }
            }
        )
    }
}
#endif
