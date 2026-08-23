import ComposableArchitecture
@testable import Feature
import XCTest

@MainActor
final class MyPageFeatureTests: XCTestCase {
    func test_프로필수정을_닫아도_시트가_내리기_전에는_본문이_남는다() async {
        let store = TestStore(initialState: MyPageFeature.State(isSkeleton: false)) {
            MyPageFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.profileEditTapped) {
            $0.profileEdit = ProfileEditFeature.State(nickname: "", selectedIconID: 1)
            $0.isProfileEditPresented = true
        }
        await store.send(.profileEditCloseRequested) {
            $0.isProfileEditPresented = false
        }
        XCTAssertNotNil(store.state.profileEdit)
    }

    func test_시트_퇴장이_끝나면_프로필수정이_nil_이다() async {
        var state = MyPageFeature.State(isSkeleton: false)
        state.profileEdit = ProfileEditFeature.State(nickname: "", selectedIconID: 1)
        state.isProfileEditPresented = false
        let store = TestStore(initialState: state) {
            MyPageFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.profileEdit(.dismiss)) {
            $0.profileEdit = nil
        }
    }

    func test_저장해도_퇴장_전에는_본문이_남고_닉네임은_바로_반영된다() async {
        var state = MyPageFeature.State(nickname: "old", iconID: 1, isSkeleton: false)
        state.profileEdit = ProfileEditFeature.State(nickname: "old", selectedIconID: 1)
        state.isProfileEditPresented = true
        let store = TestStore(initialState: state) {
            MyPageFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.profileEdit(.presented(.delegate(.saved(nickname: "new", iconID: 2))))) {
            $0.nickname = "new"
            $0.iconID = 2
            $0.isProfileEditPresented = false
        }
        XCTAssertNotNil(store.state.profileEdit)
    }
}
