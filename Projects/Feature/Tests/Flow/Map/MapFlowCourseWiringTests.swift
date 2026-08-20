import Feature
import ThirdParty
import XCTest

@MainActor
final class MapFlowCourseWiringTests: XCTestCase {

    func test_날짜검증통과_장소선택_push() async {
        var course = CourseFeature.State()
        course.date = DateComponents(year: 2030, month: 8, day: 5)
        let store = TestStore(
            initialState: MapFlowFeature.State(
                course: course,
                path: [.course]
            )
        ) {
            MapFlowFeature()
        }

        await store.send(.course(.nextTapped))
        await store.receive(\.course.delegate.placePickRequested) {
            $0.path = [.course, .coursePlacePick]
        }
    }

    func test_코스짜기_delegate_삼킴() async {
        let store = TestStore(
            initialState: MapFlowFeature.State(
                course: CourseFeature.State(),
                path: [.course, .coursePlacePick]
            )
        ) {
            MapFlowFeature()
        }

        // Cycle 5 가 코스 결과 화면을 붙이기 전까지는 아무 일도 안 일어난다
        await store.send(
            .course(
                .delegate(
                    .buildRequested(
                        date: DateComponents(year: 2030, month: 8, day: 5),
                        time: nil,
                        placeIDs: ["a"]
                    )
                )
            )
        )
    }

    func test_경로가_비면_코스State_nil() async {
        let store = TestStore(
            initialState: MapFlowFeature.State(
                course: CourseFeature.State(),
                path: [.course]
            )
        ) {
            MapFlowFeature()
        }

        await store.send(.pathChanged([])) {
            $0.path = []
            $0.course = nil
        }
    }

    func test_장소선택에서_뒤로가면_날짜화면이_남는다() async {
        let store = TestStore(
            initialState: MapFlowFeature.State(
                course: CourseFeature.State(),
                path: [.course, .coursePlacePick]
            )
        ) {
            MapFlowFeature()
        }

        await store.send(.course(.backTapped))
        await store.receive(\.course.delegate.dismissed)
        await store.receive(\.pathChanged) {
            $0.path = [.course]
        }
        XCTAssertNotNil(store.state.course)
    }

    func test_날짜화면에서_뒤로가면_코스가_닫힌다() async {
        let store = TestStore(
            initialState: MapFlowFeature.State(
                course: CourseFeature.State(),
                path: [.course]
            )
        ) {
            MapFlowFeature()
        }

        await store.send(.course(.backTapped))
        await store.receive(\.course.delegate.dismissed)
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.course = nil
        }
    }
}
