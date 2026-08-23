import Domain
import Feature
import Foundation
import ThirdParty
import XCTest

@MainActor
final class HomeFlowFeatureTests: XCTestCase {

    func test_미연결에서_캘린더를_누르면_커플연결이_열린다() async {
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(nickname: "나", partnerName: nil)
            )
        ) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.home(.calendarTapped))
        await store.receive(\.home.connectFlowRequested)
        await store.receive(\.home.delegate.connectFlowRequested) {
            $0.path = [.connect]
        }
        XCTAssertNotNil(store.state.couple)
    }

    func test_커플_세단계가_차례로_쌓인다() async {
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(nickname: "나"),
                couple: CoupleConnectFeature.State(myNickname: "나", showsSkip: false),
                path: [.connect]
            )
        ) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.couple(.delegate(.showCodeInput))) {
            $0.path = [.connect, .codeInput]
        }
        await store.send(.couple(.delegate(.showComplete))) {
            $0.path = [.connect, .codeInput, .complete]
        }
    }

    func test_커플_연결이_끝나면_스택이_닫히고_홈을_다시_읽는다() async {
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(nickname: "나"),
                couple: CoupleConnectFeature.State(myNickname: "나", showsSkip: false),
                path: [.connect, .codeInput]
            )
        ) {
            HomeFlowFeature()
        } withDependencies: {
            $0.homeClient.home = {
                HomeSummary(
                    connected: false,
                    myNickname: "나",
                    partnerNickname: nil,
                    currentDateCourse: nil
                )
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.couple(.delegate(.connected(Couple(partnerNickname: "짝", partnerIconID: 1))))) {
            $0.path = []
            $0.couple = nil
        }
        await store.receive(\.home.reloadRequested)
    }

    func test_연결됨에서_캘린더를_누르면_지난데이트가_열린다() async {
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(nickname: "나", partnerName: "짝")
            )
        ) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.home(.calendarTapped))
        await store.receive(\.home.delegate.pastDateCoursesRequested) {
            $0.path = [.pastDateCourses]
        }
        XCTAssertNotNil(store.state.pastDateCourses)
    }

    func test_지난데이트에서_뒤로가면_홈_루트로_돌아간다() async {
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(nickname: "나", partnerName: "짝"),
                pastDateCourses: PastDateCoursesFeature.State(),
                path: [.pastDateCourses]
            )
        ) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pastDateCourses(.delegate(.back))) {
            $0.path = []
            $0.pastDateCourses = nil
        }
    }

    func test_지난데이트에서_일정만들기를_누르면_코스가_위로_쌓인다() async {
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(nickname: "나", partnerName: "짝"),
                pastDateCourses: PastDateCoursesFeature.State(),
                path: [.pastDateCourses]
            )
        ) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pastDateCourses(.delegate(.createCourse))) {
            $0.path = [.pastDateCourses, .course]
        }
        XCTAssertNotNil(store.state.course)
    }

    func test_코스_날짜화면에서_뒤로가면_코스가_닫힌다() async {
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(nickname: "나"),
                course: CourseFeature.State(),
                path: [.course]
            )
        ) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.course(.delegate(.dismissed)))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.course = nil
        }
    }

    func test_저장장소_전체보기는_상위로_올라간다() async {
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(nickname: "나")
            )
        ) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.home(.delegate(.showAllSavedPlaces)))
        await store.receive(.delegate(.showAllSavedPlaces))
    }

    func test_홈_세션만료는_위로_올린다() async {
        let store = TestStore(initialState: HomeFlowFeature.State()) {
            HomeFlowFeature()
        }

        await store.send(.home(.delegate(.sessionExpired)))
        await store.receive(\.delegate.sessionExpired)

        XCTAssertEqual(store.state.path, [])
    }

    func test_커플_세션만료는_상태를_지우고_위로_올린다() async {
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(nickname: "나"),
                couple: CoupleConnectFeature.State(myNickname: "나", showsSkip: false),
                path: [.connect, .codeInput]
            )
        ) {
            HomeFlowFeature()
        }

        await store.send(.couple(.delegate(.sessionExpired))) {
            $0.couple = nil
            $0.path = []
        }
        await store.receive(\.delegate.sessionExpired)

        XCTAssertNil(store.state.couple)
        XCTAssertEqual(store.state.path, [])
    }

    func test_코스_세션만료는_상태를_지우고_위로_올린다() async {
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(nickname: "나"),
                course: CourseFeature.State(),
                path: [.course, .coursePlacePick]
            )
        ) {
            HomeFlowFeature()
        }

        await store.send(.course(.delegate(.sessionExpired))) {
            $0.course = nil
            $0.path = []
        }
        await store.receive(\.delegate.sessionExpired)

        XCTAssertNil(store.state.course)
        XCTAssertEqual(store.state.path, [])
    }

    func test_코스결과_세션만료는_상태를_지우고_위로_올린다() async {
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(nickname: "나"),
                courseResult: CourseResultFeature.State(
                    course: nil,
                    dateCourseID: "1"
                ),
                path: [.courseResult]
            )
        ) {
            HomeFlowFeature()
        } withDependencies: {
            $0.homeClient.home = {
                HomeSummary(
                    connected: false,
                    myNickname: "나",
                    partnerNickname: nil,
                    currentDateCourse: nil
                )
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.courseResult(.delegate(.sessionExpired))) {
            $0.courseResult = nil
            $0.path = []
        }
        await store.receive(\.delegate.sessionExpired)
        await store.skipReceivedActions()

        XCTAssertNil(store.state.courseResult)
        XCTAssertEqual(store.state.path, [])
    }
}
