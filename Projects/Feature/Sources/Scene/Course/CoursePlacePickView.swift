import ComposableArchitecture
import CoreImageCache
import CoreKakaoMap
import Domain
import SharedDesignSystem
import SwiftUI

// MARK: - CoursePlacePickMetric

private enum CoursePlacePickMetric {
    static let cornerRadius: CGFloat = 12
    static let skeletonRowCount = 3
    static let skeletonRowHeight: CGFloat = 64
    static let ctaButtonHeight: CGFloat = 56
    /// 목록 마지막 행과 CTA 버튼 윗면 사이
    static let listGapAboveCTA: CGFloat = 20

    /// 시트 중간 단계 비율. 기기 화면 전체 높이 대비다.
    /// 사용자가 써 본 뒤 1%p 씩 올려 정한다. 시안 대조에서 확정
    static let sheetMiddleRatio: CGFloat = 0.70

    /// 최소 시트에서 필터 아래 끝과 버튼 영역 위 끝 사이. 시안 대조에서 확정.
    /// 시안 `4991:20653` 에서 필터 칩 아래 끝 698 · 버튼 영역(위 그라데이션 포함) 위 끝 706 사이가 8 이다
    static let filterGapAboveCTA: CGFloat = Spacing.s8

    /// 「검색」 칩이 검색창으로 늘어나고 나머지 칩이 오른쪽으로 밀려 사라지는 전환.
    /// 시안 메모에 길이가 없어 실기기에서 보고 0.2초로 골랐다
    static let searchTransition: Animation = .easeInOut(duration: 0.2)
    /// 전환(0.2초)이 끝나고 50ms 뒤 키보드를 올린다. 전환 길이를 바꾸면 같이 바꾼다.
    /// 키보드 준비가 메인 스레드를 약 70ms 막아 전환과 겹치면 전환이 끊긴다
    static let searchFocusDelay: Duration = .milliseconds(250)
    static let searchChipGeometryID = "searchChip"
    /// 「취소」 글자 양옆 여백. 시안 `5054:29517` 이 글자 버튼을 좌우 6 으로 감싸 너비 37 이다
    static let searchCancelHorizontalPadding: CGFloat = 6
}

// MARK: - CoursePlacePickView

/// 코스에 담을 장소를 고르는 화면. 시안 b04 · b05 · b06 · b07.
///
/// 고른 순서가 곧 번호다.
public struct CoursePlacePickView: View {
    @Bindable private var store: StoreOf<CourseFeature>

    /// 시트 단계. 처음은 중간(`collapsed`, 화면 높이의 70%)이다. 지도를 끌어도 안 바뀐다
    @State private var sheetDetent: SheetDetent = .collapsed

    @State private var collapsedSheetTop: CGFloat = 0

    /// 시트 위 끝에서 잰 필터 줄 아래 끝. 최소 단계 높이의 근거다
    @State private var filterBottomInSheet: CGFloat = 0

    /// 필터 아래 끝을 화면 픽셀 자리로 반올림하는 근거
    @Environment(\.displayScale) private var displayScale

    /// 아래 버튼 영역(위 그라데이션 36 포함) 높이. 최소 단계 높이의 근거다.
    /// 버튼 영역과 시트가 둘 다 안전영역 바닥에 붙어, 이 높이가 곧 시트 바닥에서 버튼 영역 위 끝까지다
    @State private var ctaHeight: CGFloat = 0

    /// 검색창 포커스. 풀리면 키보드가 내려간 것으로 리듀서에 알린다
    @FocusState private var isSearchFieldFocused: Bool
    /// 「검색」 칩과 검색창을 한 모양으로 잇는 전환
    @Namespace private var searchNamespace

    /// 지금 열린 필터 메뉴. 하나만 열린다
    @State private var openFilterMenu: FilterMenu?
    @State private var ownershipMenuFrame: CGRect?
    @State private var categoryMenuFrame: CGRect?
    @State private var grabFrames: [CGRect] = []

    /// 핀을 누르면 리듀서의 요청대로 목록을 그 행까지 올린다
    @State private var listScrollPosition = ScrollPosition(idType: String.self)

    public init(store: StoreOf<CourseFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            map
            backButtonLayer
            sheet
            cta
        }
        // 키보드가 올라와도 시트와 버튼이 안 움직인다. 버튼은 키보드 뒤에 가리고,
        // 시트 높이 계산이 키보드 높이를 읽지 않는다. 지도 탭이 키보드를 시트 계산에 읽어 굳은 선례가 있다
        .ignoresSafeArea(.keyboard)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        // 네비바가 있으면 안전영역이 늘어 시트가 그만큼 내려앉는다
        .toolbar(.hidden, for: .navigationBar)
        .task { store.send(.onAppear) }
        .task(id: store.search.isFieldOpen) { await focusSearchFieldAfterExpand() }
        .onChange(of: isSearchFieldFocused) { _, isFocused in
            guard !isFocused else { return }
            store.send(.searchFieldDismissed, animation: CoursePlacePickMetric.searchTransition)
        }
        .alert(
            store.conflictAlertMessage ?? "",
            isPresented: Binding(
                get: { store.conflictAlertMessage != nil },
                set: { if !$0 { store.send(.conflictAlertDismissed) } }
            )
        ) {
            Button("확인", role: .cancel) { store.send(.conflictAlertDismissed) }
        }
        .toast(item: toastBinding)
    }
}

// MARK: - Layer

private extension CoursePlacePickView {

    /// 마지막 행이 CTA 버튼 윗면에서 20 위에 서게 시트가 그만큼 더 올라간다.
    /// 그라데이션은 안 피한다. 그 아래로 목록이 비쳐 보이는 것이 그 층의 뜻이다
    ///
    /// 아래 안전영역은 안 더한다. 이 화면의 시트와 CTA 가 둘 다 안전영역 바닥에 붙어
    /// 이미 그만큼 올라와 있다. `MapView` 는 시트가 안전영역 아래까지 뻗어 더해야 한다
    var ctaCoverPadding: CGFloat {
        Spacing.s20                                 // CTAContainer 의 버튼 아래 패딩
            + CoursePlacePickMetric.ctaButtonHeight
            + CoursePlacePickMetric.listGapAboveCTA
    }

    var map: some View {
        KakaoMapView(
            camera: Binding(
                get: { store.camera },
                set: { store.send(.cameraChanged($0)) }
            ),
            pins: store.markers.map(MapMarkerStyle.pin(for:)),
            routes: store.routes,
            userLocation: store.userLocation,
            onPinTap: { store.send(.markerTapped($0)) },
            // 화면을 누르면 키보드를 내린다
            onMapTap: { isSearchFieldFocused = false },
            collapsedSheetTop: collapsedSheetTop
        )
        .ignoresSafeArea()
        // 지도가 보이는 동안만 내 위치를 받는다. 날짜 화면에는 지도가 없어 흐름이 안 열린다.
        // 사라질 때 액션을 보내지 않는다. 뒤로 가면 상위가 상태를 먼저 지워 그 액션이 빈 자리에 닿는다
        .task { await store.send(.mapAppeared).finish() }
    }

    /// 뒤로가기가 서치바 자리에 선다. 시트 펼침 한계가 그 자리를 기준으로 잡혀 있다
    var backButtonLayer: some View {
        BackButton { store.send(.backTapped) }
            .padding(.leading, BackButtonMetric.leadingInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var sheet: some View {
        MapBottomSheet(
            selection: $sheetDetent,
            // 이 화면엔 서치바가 없다. 뒤로가기 버튼이 같은 높이에 있어 그 아래 8 에서 멈춘다
            expandLimit: .belowSearchBar,
            collapsedRatio: CoursePlacePickMetric.sheetMiddleRatio,
            minimumHeight: minimumSheetHeight,
            openMenuFrames: [ownershipMenuFrame, categoryMenuFrame].compactMap { $0 },
            grabFrames: grabFrames,
            // 끌기 시작하면 열린 메뉴를 닫는다. 열어둔 채 끌면 메뉴가 시트를 따라다녀 어색하다
            onDragBegan: { openFilterMenu = nil },
            gestureKind: .grabberOnly,
            onCollapsedTopChange: { collapsedSheetTop = $0 },
            scrollPosition: $listScrollPosition
        ) {
            EmptyView()
        } header: {
            sheetHeader
        } content: {
            sheetContent
                // 목록 · 빈 화면을 누르면 키보드를 내린다. 행 탭과 함께 받아, 입력 중 행을 누르면 고르기도 한다
                .simultaneousGesture(TapGesture().onEnded { isSearchFieldFocused = false })
        }
        // 요청 번호까지 보므로 같은 행을 다시 요청해도 다시 맞춘다. 시트 높이는 건드리지 않는다
        .onChange(of: store.rowScrollRequest) { _, request in
            guard let request else { return }
            withAnimation {
                listScrollPosition.scrollTo(id: request.placeID, anchor: .top)
            }
        }
        // 목록을 스크롤하면 키보드를 내린다
        .scrollDismissesKeyboard(.immediately)
    }

    /// 화면 아래에 고정된 CTA. 시트를 올려도 화면에서 자리가 안 바뀐다 (b04 · b06 · b07)
    var cta: some View {
        CTAContainer {
            AppButton(store.ctaTitle, style: .dark, size: .xl, fullWidth: true) {
                store.send(.buildTapped)
            }
            .disabled(!store.isCTAEnabled)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            ctaHeight = height
        }
    }

    var sheetHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Text("저장한 장소")
                .typography(.title3SB)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                    if grabFrames != [$0] { grabFrames = [$0] }
                }

            filterRow
        }
        // 최소 단계 높이의 근거. 제목부터 필터 줄 아래 끝까지의 크기를 잰다.
        // 카드 안 자리는 시트가 오르내리는 동안 바뀌어 크기로 잰다. 크기는 .offset 이동에 영향받지 않는다
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            filterBottomInSheet = SheetLayout.filterBottomInSheet(
                grabberAreaHeight: MapBottomSheetMetric.grabberAreaHeight,
                headerHeightToFilter: height,
                displayScale: displayScale
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 시안 `5041:43209` 머리 여백은 왼쪽 20 · 오른쪽 12 다. 검색창이 줄 끝까지 늘어 오른쪽 값이 보인다
        .padding(.leading, Spacing.s20)
        .padding(.trailing, Spacing.s12)
        .padding(.bottom, Spacing.s8)
    }

    /// 필터 줄. 검색창이 열리면 「검색」 칩이 줄 너비로 늘어나 검색창이 되고, 나머지 칩은 오른쪽으로 밀려 사라진다.
    /// 두 모양이 같은 높이라 바뀌어도 머리 높이와 최소 단계가 그대로다
    var filterRow: some View {
        HStack(spacing: Spacing.s8) {
            if store.search.isFieldOpen {
                // 검색창이 남는 너비를 다 차지해 「취소」 가 줄 오른쪽 끝에 붙는다
                searchFieldItems
            } else {
                chipItems
                Spacer(minLength: 0)
            }
        }
        .frame(height: SavedPlaceSearchChipMetric.height)
    }

    @ViewBuilder
    var searchFieldItems: some View {
        SavedPlaceSearchField(
            text: searchQueryBinding,
            isFocused: $isSearchFieldFocused,
            // 검색 키는 키보드만 내린다. 내려가면 검색어 칩이 된다
            onSubmit: { isSearchFieldFocused = false }
        )
        .matchedGeometryEffect(id: CoursePlacePickMetric.searchChipGeometryID, in: searchNamespace)

        Button {
            // 입력칸이 포커스를 쥔 채 화면에서 빠지면 키보드가 애니메이션 없이 사라진다. 먼저 내린다.
            // 포커스 값만 바꾸면 입력칸이 빠지는 것과 같은 갱신에 반영돼 늦어서 키보드를 바로 내린다
            isSearchFieldFocused = false
            dismissKeyboard()
            store.send(.searchCancelTapped, animation: CoursePlacePickMetric.searchTransition)
        } label: {
            Text("취소")
                .typography(.body2SB)
                .foregroundStyle(Color.textTertiary)
                .padding(.horizontal, CoursePlacePickMetric.searchCancelHorizontalPadding)
                .frame(height: SavedPlaceSearchChipMetric.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    @ViewBuilder
    var chipItems: some View {
        SavedPlaceSearchChip(
            query: store.search.query,
            onTap: openSearchField,
            onClear: {
                store.send(.searchChipClearTapped, animation: CoursePlacePickMetric.searchTransition)
            }
        )
        .disabled(!store.isSearchAvailable)
        .opacity(store.isSearchAvailable ? 1 : SavedPlaceSearchChipMetric.disabledOpacity)
        .matchedGeometryEffect(id: CoursePlacePickMetric.searchChipGeometryID, in: searchNamespace)

        // 드롭다운은 제 너비를 지킨다. 줄이 모자라면 검색어 칩의 글자가 줄어든다
        Group {
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
                placeholder: PlaceCategory.placeholderName,
                options: [PlaceCategory.unfilteredName] + PlaceCategory.mapDisplayOrder.map(\.displayName),
                onMenuFrameChange: { categoryMenuFrame = $0 }
            )
        }
        .fixedSize()
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    @ViewBuilder
    var sheetContent: some View {
        switch store.listContent {
        case .skeleton:
            skeleton
        case .loadFailed:
            failureState
        case .noSavedPlace:
            emptyState(title: "저장한 장소가 없어요", message: "마음에 드는 장소를 저장해보세요")
        case .noMatch:
            emptyState(title: "조건에 맞는 장소가 없어요", message: "필터를 바꿔보세요")
        case .noSearchResult:
            emptyState(title: "검색 결과가 없어요", message: "다른 검색어를 입력해주세요")
        case .searchFailed:
            emptyState(title: "검색에 실패했어요", message: "잠시 뒤 다시 시도해주세요")
        case .list:
            placeList
        }
    }

    var placeList: some View {
        LazyVStack(spacing: 0) {
            ForEach(store.filteredPlaces) { candidate in
                row(candidate, showsDivider: candidate.id != store.filteredPlaces.last?.id)
            }
            if store.isSearching && store.search.hasNext {
                searchEndMarker
            }
        }
        // 시트 스크롤이 ForEach 가 매긴 장소 id 로 행을 찾는다
        .scrollTargetLayout()
        .padding(.top, Spacing.s8)
        .padding(.bottom, ctaCoverPadding)
    }

    /// 검색 결과 목록 끝. 스크롤 영역 안에 들어오면 다음 페이지를 부른다.
    /// 페이지마다 새 id 를 받아, 받은 페이지가 짧아 끝이 계속 보이면 처음 값으로 다시 부른다
    var searchEndMarker: some View {
        Color.clear
            .frame(height: 1)
            .id(store.search.page)
            .onGeometryChange(for: Bool.self) { proxy in
                guard let visible = proxy.bounds(of: .scrollView) else { return false }
                return CGRect(origin: .zero, size: proxy.size).intersects(visible)
            } action: { isVisible in
                if isVisible { store.send(.searchReachedEnd) }
            }
    }

    func row(_ candidate: SavedPlace, showsDivider: Bool) -> some View {
        let badge = store.state.badgeState(for: candidate.id)

        return PlaceListRow(
            icon: candidate.place.category.icon,
            name: candidate.alias ?? candidate.place.name,
            address: candidate.place.address,
            showsDivider: showsDivider,
            thumbnailURLs: candidate.place.thumbnailURLs,
            isNameSensitive: candidate.alias != nil
        ) { url in
            RemoteImage(url: url, cornerRadius: CoursePlacePickMetric.cornerRadius)
        } trailing: {
            PlaceNumberBadge(state: badge)
        }
        // 배경은 행이 안 칠한다. 고른 행만 여기서 연분홍을 얹는다 (b06)
        .background(badge == .unselected ? Color.clear : Color.brandSurface)
        .contentShape(Rectangle())
        .onTapGesture { store.send(.rowTapped(candidate.id)) }
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
                image: .emptyResult,
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

    func emptyState(title: String, message: String) -> some View {
        EmptyStateView(
            image: .emptyResult,
            title: title,
            message: message
        )
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.s32)
        .padding(.bottom, ctaCoverPadding)
    }

    /// 메뉴 하나의 열림 바인딩. 하나를 열면 다른 하나가 저절로 닫힌다.
    /// 최소에서 열면 시트를 중간으로 올린다. 드롭다운이 필터 아래로 펼쳐져 버튼 영역에 가리기 때문이다
    func filterMenuBinding(_ menu: FilterMenu) -> Binding<Bool> {
        Binding(
            get: { openFilterMenu == menu },
            set: { isOpen in
                if isOpen {
                    let next = SheetLayout.detentForOpeningMenu(sheetDetent)
                    if sheetDetent != next {
                        sheetDetent = next
                    }
                }
                openFilterMenu = isOpen ? menu : nil
            }
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

    var toastBinding: Binding<ToastState?> {
        Binding(
            get: { store.toast },
            set: { newValue in
                if newValue == nil {
                    store.send(.toastDismissed)
                }
            }
        )
    }

    var searchQueryBinding: Binding<String> {
        Binding(
            get: { store.search.query },
            set: { store.send(.searchQueryChanged($0)) }
        )
    }

    /// 열린 메뉴를 닫고, 최소면 시트를 중간으로 올린 뒤 검색창을 연다.
    /// 최소에서는 검색 결과가 버튼 영역에 가린다. 필터 메뉴를 열 때와 같은 규칙이다
    func openSearchField() {
        openFilterMenu = nil
        let next = SheetLayout.detentForOpeningMenu(sheetDetent)
        if sheetDetent != next {
            sheetDetent = next
        }
        store.send(.searchChipTapped, animation: CoursePlacePickMetric.searchTransition)
    }

    /// 칩이 다 늘어난 뒤에 키보드를 올린다. 그사이 검색창이 닫히면 안 올린다
    func focusSearchFieldAfterExpand() async {
        guard store.search.isFieldOpen else { return }
        try? await Task.sleep(for: CoursePlacePickMetric.searchFocusDelay)
        guard !Task.isCancelled, store.search.isFieldOpen else { return }
        isSearchFieldFocused = true
    }

    /// 최소 단계 높이. 필터 아래 끝과 버튼 영역 위 끝 사이가 시안 간격이 된다. 둘 중 하나를 아직 못 쟀으면 `nil` 이다
    var minimumSheetHeight: CGFloat? {
        SheetLayout.minimumHeight(
            filterBottomInSheet: filterBottomInSheet,
            gap: CoursePlacePickMetric.filterGapAboveCTA,
            obstacleHeight: ctaHeight
        )
    }
}
