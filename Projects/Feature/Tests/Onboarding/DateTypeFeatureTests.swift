import Domain
import Feature
import ThirdParty
import XCTest

@MainActor
final class DateTypeFeatureTests: XCTestCase {
    private let preference = DatePreference(
        indoorOutdoor: .indoor,
        activityLevel: .active,
        dateTime: .day,
        dateFocus: .food
    )

    private var profile: UserProfile {
        UserProfile(
            nickname: "둘픽",
            iconID: 1,
            datePreference: preference
        )
    }

    private var allSelectedState: DateTypeFeature.State {
        DateTypeFeature.State(
            indoorOutdoor: .indoor,
            activityLevel: .active,
            dateTime: .day,
            dateFocus: .food
        )
    }

    func test_일부만선택_저장버튼_비활성() async {
        let store = TestStore(initialState: DateTypeFeature.State()) {
            DateTypeFeature()
        }

        XCTAssertFalse(store.state.isSaveEnabled)

        await store.send(.indoorOutdoorSelected(.indoor)) {
            $0.indoorOutdoor = .indoor
        }
        XCTAssertFalse(store.state.isSaveEnabled)

        await store.send(.activityLevelSelected(.active)) {
            $0.activityLevel = .active
        }
        XCTAssertFalse(store.state.isSaveEnabled)

        await store.send(.dateTimeSelected(.day)) {
            $0.dateTime = .day
        }
        XCTAssertFalse(store.state.isSaveEnabled)
        XCTAssertNil(store.state.datePreference)
    }

    func test_네축전부선택_저장버튼_활성() async {
        let store = TestStore(initialState: DateTypeFeature.State()) {
            DateTypeFeature()
        }

        await store.send(.indoorOutdoorSelected(.outdoor)) {
            $0.indoorOutdoor = .outdoor
        }
        await store.send(.activityLevelSelected(.static)) {
            $0.activityLevel = .static
        }
        await store.send(.dateTimeSelected(.night)) {
            $0.dateTime = .night
        }
        await store.send(.dateFocusSelected(.sightseeing)) {
            $0.dateFocus = .sightseeing
        }

        XCTAssertTrue(store.state.isSaveEnabled)
        XCTAssertEqual(
            store.state.datePreference,
            DatePreference(
                indoorOutdoor: .outdoor,
                activityLevel: .static,
                dateTime: .night,
                dateFocus: .sightseeing
            )
        )
    }

    func test_저장중_저장버튼_비활성() async {
        var state = allSelectedState
        state.isSubmitting = true
        let store = TestStore(initialState: state) {
            DateTypeFeature()
        }

        XCTAssertFalse(store.state.isSaveEnabled)
        XCTAssertNotNil(store.state.datePreference)
    }

    func test_저장성공_저장델리게이트_전달() async {
        let requestedPreference = LockIsolated<DatePreference?>(nil)
        let profile = self.profile
        let store = TestStore(initialState: allSelectedState) {
            DateTypeFeature()
        } withDependencies: {
            $0.profileClient.updateDatePreference = { preference in
                requestedPreference.setValue(preference)
                return profile
            }
        }

        await store.send(.saveButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateDatePreferenceResponse.success) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.saved)

        XCTAssertEqual(requestedPreference.value, preference)
    }

    func test_건너뛰기_클라이언트_호출없이_델리게이트() async {
        let didCallClient = LockIsolated(false)
        let profile = self.profile
        let store = TestStore(initialState: allSelectedState) {
            DateTypeFeature()
        } withDependencies: {
            $0.profileClient.updateDatePreference = { _ in
                didCallClient.setValue(true)
                return profile
            }
        }

        await store.send(.skipButtonTapped)
        await store.receive(\.delegate.skipped)

        XCTAssertFalse(didCallClient.value)
    }

    func test_툴팁버튼_열고_닫기() async {
        let store = TestStore(initialState: DateTypeFeature.State()) {
            DateTypeFeature()
        }

        await store.send(.tooltipButtonTapped) {
            $0.isTooltipPresented = true
        }
        await store.send(.tooltipButtonTapped) {
            $0.isTooltipPresented = false
        }
    }

    func test_툴팁없을때_화면터치_변화없음() async {
        let store = TestStore(initialState: DateTypeFeature.State()) {
            DateTypeFeature()
        }

        await store.send(.tooltipDismissed)
    }

    func test_축선택_툴팁닫히고_선택유지() async {
        let store = TestStore(initialState: DateTypeFeature.State(isTooltipPresented: true)) {
            DateTypeFeature()
        }

        await store.send(.indoorOutdoorSelected(.indoor)) {
            $0.indoorOutdoor = .indoor
            $0.isTooltipPresented = false
        }

        await store.send(.tooltipButtonTapped) {
            $0.isTooltipPresented = true
        }
        await store.send(.activityLevelSelected(.active)) {
            $0.activityLevel = .active
            $0.isTooltipPresented = false
        }

        await store.send(.tooltipButtonTapped) {
            $0.isTooltipPresented = true
        }
        await store.send(.dateTimeSelected(.day)) {
            $0.dateTime = .day
            $0.isTooltipPresented = false
        }

        await store.send(.tooltipButtonTapped) {
            $0.isTooltipPresented = true
        }
        await store.send(.dateFocusSelected(.food)) {
            $0.dateFocus = .food
            $0.isTooltipPresented = false
        }

        XCTAssertEqual(store.state.datePreference, preference)
    }

    func test_건너뛰기_툴팁닫고_델리게이트() async {
        var state = allSelectedState
        state.isTooltipPresented = true
        let store = TestStore(initialState: state) {
            DateTypeFeature()
        }

        await store.send(.skipButtonTapped) {
            $0.isTooltipPresented = false
        }
        await store.receive(\.delegate.skipped)
    }

    func test_저장_툴팁닫힘() async {
        var state = allSelectedState
        state.isTooltipPresented = true
        let profile = self.profile
        let store = TestStore(initialState: state) {
            DateTypeFeature()
        } withDependencies: {
            $0.profileClient.updateDatePreference = { _ in profile }
        }

        await store.send(.saveButtonTapped) {
            $0.isSubmitting = true
            $0.isTooltipPresented = false
        }
        await store.receive(\.updateDatePreferenceResponse.success) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.saved)
    }

    func test_인증실패_세션만료_델리게이트() async {
        let store = TestStore(initialState: allSelectedState) {
            DateTypeFeature()
        } withDependencies: {
            $0.profileClient.updateDatePreference = { _ in throw ProfileError.unauthorized }
        }

        await store.send(.saveButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateDatePreferenceResponse.failure) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.sessionExpired)
    }

    func test_네트워크실패_토스트_노출() async {
        let store = TestStore(initialState: allSelectedState) {
            DateTypeFeature()
        } withDependencies: {
            $0.profileClient.updateDatePreference = { _ in throw ProfileError.network }
        }

        await store.send(.saveButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateDatePreferenceResponse.failure) {
            $0.isSubmitting = false
            $0.toast = .error("네트워크 연결을 확인해 주세요.")
        }

        await store.send(.dismissToast) {
            $0.toast = nil
        }
    }

    func test_알수없는실패_토스트_노출() async {
        let store = TestStore(initialState: allSelectedState) {
            DateTypeFeature()
        } withDependencies: {
            $0.profileClient.updateDatePreference = { _ in throw ProfileError.unknown }
        }

        await store.send(.saveButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateDatePreferenceResponse.failure) {
            $0.isSubmitting = false
            $0.toast = .error("잠시 후 다시 시도해 주세요.")
        }
    }
}
