import ComposableArchitecture
import Domain
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

    func test_공지사항_줄을_누르면_공지_목록을_위로_올린다() async {
        let store = TestStore(initialState: MyPageFeature.State(isSkeleton: false)) {
            MyPageFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.noticeTapped)
        await store.receive(\.delegate.noticeRequested)
    }

    func test_알림설정을_받으면_스켈레톤이_걷히고_토글이_채워진다() async {
        let store = TestStore(initialState: MyPageFeature.State()) {
            MyPageFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        let settings = NotificationSettings(
            contentSavedEnabled: true,
            dateScheduleEnabled: false,
            marketingEnabled: true,
            marketingConsentVersion: "v1",
            availableMarketingConsentVersion: "v2"
        )
        await store.send(.notificationSettingsLoaded(settings)) {
            $0.isSkeleton = false
            $0.savedContentAlarmOn = true
            $0.dateScheduleAlarmOn = false
            $0.marketingAlarmOn = true
            $0.marketingConsentVersion = "v1"
            $0.availableMarketingConsentVersion = "v2"
        }
    }

    func test_알림설정_조회에_실패해도_스켈레톤은_걷힌다() async {
        let store = TestStore(initialState: MyPageFeature.State()) {
            MyPageFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.notificationSettingsLoadFailed) {
            $0.isSkeleton = false
        }
    }

    func test_알림설정_저장에_실패하면_서버_값을_다시_불러온다() async {
        let served = NotificationSettings(
            contentSavedEnabled: true,
            dateScheduleEnabled: true,
            marketingEnabled: false
        )
        let store = TestStore(initialState: MyPageFeature.State(isSkeleton: false)) {
            MyPageFeature()
        } withDependencies: {
            $0.notificationClient.notificationSettings = { served }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.notificationSettingsUpdateFailed)
        await store.receive(\.notificationSettingsLoaded) {
            $0.savedContentAlarmOn = true
            $0.dateScheduleAlarmOn = true
            $0.marketingAlarmOn = false
        }
    }
}
