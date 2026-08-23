import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct MapFlowView: View {
    @Bindable public var store: StoreOf<MapFlowFeature>

    /// 아래 안전영역(탭바 + 홈 인디케이터). 상세 시트 목록 아래 여백에 더한다
    @State private var bottomInset: CGFloat = 0

    /// 상세 시트 층의 높이. 게시글이 뜰 때 장소 상세를 이만큼 아래로 치운다
    @State private var layerHeight: CGFloat = 0

    /// 게시글 상세 층의 높이. 핀 탭으로 장소 상세가 올라올 때 게시글을 이만큼 아래로 치운다
    @State private var postLayerHeight: CGFloat = 0

    public init(store: StoreOf<MapFlowFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: pathBinding) {
            mapRoot
                .navigationDestination(for: MapFlowFeature.Route.self) { route in
                    destination(route)
                }
        }
    }

    @ViewBuilder
    private func destination(_ route: MapFlowFeature.Route) -> some View {
        switch route {
        case .postDetail:
            Text("게시글 상세 화면 준비 중")
        case .search:
            if let searchStore = store.scope(state: \.placeSearch, action: \.placeSearch) {
                PlaceSearchView(store: searchStore)
            }
        case .course:
            if let courseStore { CourseDateView(store: courseStore) }
        case .coursePlacePick:
            if let courseStore { CoursePlacePickView(store: courseStore) }
        case .courseResult:
            if let courseResultStore { CourseResultView(store: courseResultStore) }
        }
    }

    private var mapStore: StoreOf<MapFeature> {
        store.scope(state: \.map, action: \.map)
    }

    private var courseStore: StoreOf<CourseFeature>? {
        store.scope(state: \.course, action: \.course)
    }

    private var courseResultStore: StoreOf<CourseResultFeature>? {
        store.scope(state: \.courseResult, action: \.courseResult)
    }

    // 지도 목적지 스택은 MapFlowFeature 가 소유하고, NavigationStack 이 그 path 를 그대로 민다
    private var pathBinding: Binding<[MapFlowFeature.Route]> {
        Binding(
            get: { store.path },
            set: { store.send(.pathChanged($0)) }
        )
    }
}

private extension MapFlowView {
    /// 지도 위에 상세를 얹고, 별칭은 안전영역을 무시한 층 밖에 건다
    var mapRoot: some View {
        ZStack {
            bottomInsetProbe
            ZStack(alignment: .bottom) {
                MapView(store: mapStore)
                detailLayer
                postDetailLayer
            }
        }
        // 탭바는 저장한 장소 시트일 때만 보인다. 나머지 다섯은 숨긴다
        // (분해 문서 `2026-08-13-map-course-ui-split.md:194-200` 표가 SSOT)
        .toolbar(isTabBarShown ? .automatic : .hidden, for: .tabBar)
        // 키보드 영역까지 지운 지도 층 밖에 건다. 안에 걸면 저장 버튼이 키보드에 가린다
        .bottomSheet(isPresented: aliasSheetBinding) {
            if let aliasStore = store.scope(state: \.alias, action: \.alias.presented) {
                PlaceAliasView(store: aliasStore)
            }
        }
    }

    /// 저장한 장소 시트만 탭바를 띄운다.
    /// 별칭 · 장소 상세 · 게시글 상세는 지도 위에 얹히고, 검색 결과는 같은 시트를 갈아 쓴다
    var isTabBarShown: Bool {
        store.alias == nil
            && store.detail == nil
            && store.postDetail == nil
            && !store.map.isSearching
    }

    /// 장소 상세 시트. 저장 목록 시트를 덮는다.
    /// 펼침은 검색바 아래에서 멈추고, 시트 밖은 터치를 안 가로채 검색바가 그대로 눌린다.
    /// 아래 안전영역만 무시한다. 지도 전체를 감싸면 목록 시트가 재는 아래 여백이 0 이 된다
    @ViewBuilder
    var detailLayer: some View {
        ZStack(alignment: .bottom) {
            if let detailStore = store.scope(state: \.detail, action: \.detail.presented) {
                // 장소가 바뀌어도 if let 은 참이라 시트가 남는다. id 로 뷰를 갈아야 detent·스크롤이 초기화된다
                PlaceDetailView(store: detailStore, bottomInset: bottomInset)
                    .id(detailStore.id)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .identity))
                    .ignoresSafeArea(edges: .bottom)
                    // 게시글이 위에 뜨면(장소 상세 → 게시글 순서) 장소 상세를 트리에서 빼지 않고 아래로 치운다.
                    // 빼면 시트 단계와 스크롤이 날아간다. 게시글을 닫으면 보던 자리 그대로 다시 올라온다.
                    // 게시글 핀 모드에선 장소 상세가 위라 치우지 않는다
                    .offset(y: isPlaceDetailCovered ? layerHeight : 0)
                    // 치울 때는 즉시, 올릴 때만 스프링. 사라지는 시트는 안 움직인다는 규칙에 맞춘다
                    .animation(
                        isPlaceDetailCovered ? nil : MapBottomSheetMetric.settle,
                        value: isPlaceDetailCovered
                    )
                    .allowsHitTesting(!isPlaceDetailCovered)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { layerHeight = $0 }
        .animation(
            MapBottomSheetMetric.settle,
            value: store.detail == nil
        )
    }

    /// 게시글 상세 시트. 장소 상세 위에 얹힌다.
    /// 아래 안전영역만 무시한다. 지도 전체를 감싸면 목록 시트가 재는 아래 여백이 0 이 된다
    @ViewBuilder
    var postDetailLayer: some View {
        ZStack(alignment: .bottom) {
            if let postDetailStore = store.scope(state: \.postDetail, action: \.postDetail.presented) {
                PostDetailView(store: postDetailStore, bottomInset: bottomInset)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .identity))
                    .ignoresSafeArea(edges: .bottom)
                    // 게시글 핀을 눌러 장소 상세가 위로 올라오면 게시글 상세를 아래로 치운다.
                    // 트리에 남겨 둬 장소 상세를 닫으면 보던 자리 그대로 다시 올라온다
                    .offset(y: isPostDetailCovered ? postLayerHeight : 0)
                    .allowsHitTesting(!isPostDetailCovered)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { postLayerHeight = $0 }
        // 치울 때는 즉시, 올릴 때만 스프링. 등장·퇴장도 같은 스프링을 탄다
        .animation(
            isPostDetailCovered ? nil : MapBottomSheetMetric.settle,
            value: isPostDetailCovered
        )
        .animation(
            MapBottomSheetMetric.settle,
            value: store.postDetail == nil
        )
    }

    /// 원래 흐름(장소 상세 → 게시글)에서 게시글이 위에 떠 장소 상세가 아래로 치워지는 상태
    var isPlaceDetailCovered: Bool {
        store.postDetail != nil && !store.showsContentPins
    }

    /// 게시글 핀 모드에서 장소 상세가 위로 올라와 게시글 상세가 아래로 치워지는 상태
    var isPostDetailCovered: Bool {
        store.detail != nil && store.showsContentPins
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
        .allowsHitTesting(false)
    }

    var aliasSheetBinding: Binding<Bool> {
        Binding(
            get: { store.alias != nil },
            set: { isPresented in
                // 딤 탭도 화면이 스스로 닫는 길을 타야 `cancelled` 가 상위까지 간다
                if !isPresented {
                    store.send(.alias(.presented(.dismissed)))
                }
            }
        )
    }
}
