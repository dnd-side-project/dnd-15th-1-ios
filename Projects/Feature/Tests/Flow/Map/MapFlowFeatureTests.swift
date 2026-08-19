import Feature
import ThirdParty
import XCTest

@MainActor
final class MapFlowFeatureTests: XCTestCase {
    func test_핀을_탭하면_장소_상세_경로가_쌓인다() async {
        let store = TestStore(initialState: MapFlowFeature.State()) {
            MapFlowFeature()
        }

        await store.send(.map(.markerTapped("7")))
        await store.receive(\.map.delegate.placeSelected) {
            $0.path = [.placeDetail("7")]
        }
    }

    func test_행을_탭해도_같은_경로가_쌓인다() async {
        let store = TestStore(initialState: MapFlowFeature.State()) {
            MapFlowFeature()
        }

        await store.send(.map(.rowTapped("7")))
        await store.receive(\.map.delegate.placeSelected) {
            $0.path = [.placeDetail("7")]
        }
    }

    func test_검색바와_코스_버튼이_각자_경로를_쌓는다() async {
        let store = TestStore(initialState: MapFlowFeature.State()) {
            MapFlowFeature()
        }

        await store.send(.map(.searchBarTapped))
        await store.receive(\.map.delegate.searchRequested) {
            $0.path = [.search]
        }

        await store.send(.map(.courseButtonTapped))
        await store.receive(\.map.delegate.courseRequested) {
            $0.path = [.search, .course]
        }
    }

    func test_뷰가_경로를_비우면_지도로_돌아온다() async {
        let store = TestStore(
            initialState: MapFlowFeature.State(path: [.placeDetail("7"), .search])
        ) {
            MapFlowFeature()
        }

        await store.send(.pathChanged([.placeDetail("7")])) {
            $0.path = [.placeDetail("7")]
        }
        await store.send(.pathChanged([])) {
            $0.path = []
        }
    }

    func test_수정_삭제는_화면_이동이_아니라_경로를_안_바꾼다() async {
        let store = TestStore(
            initialState: MapFlowFeature.State(map: MapFeature.State())
        ) {
            MapFlowFeature()
        }

        // PlaceClient 에 계약이 생기면 데이터 갱신으로 받는다. path 를 쓰지 않는다
        await store.send(.map(.delegate(.editRequested("7"))))
        await store.send(.map(.delegate(.deleteRequested("7"))))

        XCTAssertEqual(store.state.path, [])
    }

    func test_세션_만료는_경로를_안_쌓고_위로_올린다() async {
        let store = TestStore(initialState: MapFlowFeature.State()) {
            MapFlowFeature()
        }

        // 전역 에러라 RootFlow 까지 올라가야 로그인으로 되돌아간다
        await store.send(.map(.delegate(.sessionExpired)))
        await store.receive(\.delegate.sessionExpired)

        XCTAssertEqual(store.state.path, [])
    }
}
