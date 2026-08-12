@testable import Feature
import ThirdParty
import XCTest

final class FeatureLogReducerTests: XCTestCase {

    func test_actionParser_case_and_payload() {
        enum SampleAction {
            case loginButtonTapped(provider: String)
            case onAppear
        }

        let parsed = FeatureLogActionParser.nameAndPayload(SampleAction.loginButtonTapped(provider: "apple"))
        XCTAssertEqual(parsed.name, "loginButtonTapped")
        XCTAssertEqual(parsed.payload, "provider=apple")

        let appear = FeatureLogActionParser.nameAndPayload(SampleAction.onAppear)
        XCTAssertEqual(appear.name, "onAppear")
        XCTAssertNil(appear.payload)
    }

    func test_stateDiff_top_level_fields_only() {
        struct SampleState: Equatable {
            var isLoading = false
            var count = 0
            var child = "a"
        }

        let old = SampleState(isLoading: false, count: 0, child: "a")
        let new = SampleState(isLoading: true, count: 0, child: "b")
        let changes = FeatureLogStateDiff.changedFields(from: old, to: new)

        XCTAssertEqual(changes.map(\.field), ["isLoading", "child"])
        XCTAssertEqual(changes.first(where: { $0.field == "isLoading" })?.from, "false")
        XCTAssertEqual(changes.first(where: { $0.field == "isLoading" })?.to, "true")
    }

    func test_normalizedFieldLabel_strips_storage_and_ignores_bookkeeping() {
        XCTAssertEqual(FeatureLogStateDiff.normalizedFieldLabel("isLoading"), "isLoading")
        XCTAssertEqual(FeatureLogStateDiff.normalizedFieldLabel("_isLoading"), "isLoading")
        XCTAssertEqual(FeatureLogStateDiff.normalizedFieldLabel("_phase"), "phase")
        XCTAssertEqual(FeatureLogStateDiff.normalizedFieldLabel("_toast"), "toast")
        XCTAssertNil(FeatureLogStateDiff.normalizedFieldLabel("_$observationRegistrar"))
        XCTAssertNil(FeatureLogStateDiff.normalizedFieldLabel("_$id"))
    }

    func test_stateDiff_normalizes_observableState_storage_labels() {
        // @ObservableState stores members as `_field` + `_$...` bookkeeping.
        struct ObservableLikeState: Equatable, CustomReflectable {
            var isLoading = false
            var phase = "bootstrapping"
            var toast: String?
            var observationRegistrar = 0
            var home = "noise"

            var customMirror: Mirror {
                Mirror(
                    self,
                    children: [
                        "_isLoading": isLoading,
                        "_phase": phase,
                        "_toast": toast as Any,
                        "_$observationRegistrar": observationRegistrar,
                        "_home": home
                    ],
                    displayStyle: .struct
                )
            }
        }

        let old = ObservableLikeState(
            isLoading: false,
            phase: "bootstrapping",
            toast: nil,
            observationRegistrar: 0,
            home: "a"
        )
        let new = ObservableLikeState(
            isLoading: true,
            phase: "main",
            toast: "failed",
            observationRegistrar: 1,
            home: "b"
        )

        let changes = FeatureLogStateDiff.changedFields(from: old, to: new)
        let fields = changes.map(\.field)

        XCTAssertEqual(fields, ["isLoading", "phase", "toast", "home"])
        XCTAssertFalse(fields.contains { $0.hasPrefix("_") })
        XCTAssertFalse(fields.contains { $0.hasPrefix("_$") || $0.contains("observationRegistrar") })

        XCTAssertEqual(changes.first(where: { $0.field == "isLoading" })?.from, "false")
        XCTAssertEqual(changes.first(where: { $0.field == "isLoading" })?.to, "true")
        XCTAssertEqual(changes.first(where: { $0.field == "phase" })?.from, "bootstrapping")
        XCTAssertEqual(changes.first(where: { $0.field == "phase" })?.to, "main")
        XCTAssertEqual(changes.first(where: { $0.field == "toast" })?.from, "nil")
        XCTAssertEqual(changes.first(where: { $0.field == "toast" })?.to, "failed")
    }

    func test_shouldIgnoreField_and_navigationStyle() {
        XCTAssertTrue(FeatureLogStateDiff.shouldIgnoreField("home"))
        XCTAssertTrue(FeatureLogStateDiff.shouldIgnoreField("explore"))
        XCTAssertTrue(FeatureLogStateDiff.shouldIgnoreField("appCoordinator"))
        XCTAssertFalse(FeatureLogStateDiff.shouldIgnoreField("isLoading"))
        XCTAssertFalse(FeatureLogStateDiff.shouldIgnoreField("phase"))

        XCTAssertEqual(
            FeatureLogStateDiff.navigationStyle(field: "phase", from: "bootstrapping", to: "main"),
            .phase
        )
        XCTAssertEqual(
            FeatureLogStateDiff.navigationStyle(field: "selectedTab", from: "home", to: "map"),
            .tab
        )
        XCTAssertEqual(
            FeatureLogStateDiff.navigationStyle(field: "pendingDeepLink", from: "nil", to: "dulpick://map"),
            .deepLink
        )
        XCTAssertEqual(
            FeatureLogStateDiff.navigationStyle(field: "search", from: "nil", to: "presented"),
            .present
        )
        XCTAssertEqual(
            FeatureLogStateDiff.navigationStyle(field: "presentedTerms", from: "presented", to: "nil"),
            .dismiss
        )
        XCTAssertEqual(
            FeatureLogStateDiff.navigationStyle(field: "search", from: "presented", to: "presented"),
            .present
        )
        XCTAssertNil(
            FeatureLogStateDiff.navigationStyle(field: "isLoading", from: "false", to: "true")
        )
    }

    func test_becameUserVisible_uses_public_field_names() {
        let visible = FeatureLogStateDiff.becameUserVisible(
            from: [
                .init(field: "toast", from: "nil", to: "로그인에 실패했어요"),
                .init(field: "isLoading", from: "true", to: "false")
            ]
        )
        XCTAssertTrue(visible)

        let errorMessageVisible = FeatureLogStateDiff.becameUserVisible(
            from: [.init(field: "errorMessage", from: "nil", to: "network")]
        )
        XCTAssertTrue(errorMessageVisible)

        let notVisible = FeatureLogStateDiff.becameUserVisible(
            from: [
                .init(field: "toast", from: "old", to: "new"),
                .init(field: "_toast", from: "nil", to: "x")
            ]
        )
        XCTAssertFalse(notVisible)
    }

    func test_summarizeValue_enum_case_name_only() {
        enum Phase {
            case bootstrapping
            case loggedOut(String)
            case main(nested: NestedState)
            case appIntro
        }

        struct NestedState: Equatable {
            var isLoading = true
            var title = "home"
        }

        enum Tab {
            case home
            case map
            case explore
            case myPage
        }

        // No payload: case name only
        XCTAssertEqual(FeatureLog.summarizeValue(Phase.bootstrapping), "bootstrapping")
        XCTAssertEqual(FeatureLog.summarizeValue(Phase.appIntro), "appIntro")
        XCTAssertEqual(FeatureLog.summarizeValue(Tab.home), "home")
        XCTAssertEqual(FeatureLog.summarizeValue(Tab.map), "map")

        // With payload: case label only — never nested State dump
        let loggedOut = FeatureLog.summarizeValue(Phase.loggedOut("token"))
        XCTAssertEqual(loggedOut, "loggedOut")
        XCTAssertFalse(loggedOut.contains("token"))

        let main = FeatureLog.summarizeValue(Phase.main(nested: NestedState()))
        XCTAssertEqual(main, "main")
        XCTAssertFalse(main.contains("NestedState"))
        XCTAssertFalse(main.contains("isLoading"))
        XCTAssertFalse(main.contains("home"))
    }

    func test_stateDiff_phase_enum_summarizes_case_only() {
        enum Phase: Equatable {
            case bootstrapping
            case loggedOut(AuthLikeState)
            case main(MainLikeState)
        }

        struct AuthLikeState: Equatable {
            var isLoading = false
            var provider = "apple"
        }

        struct MainLikeState: Equatable {
            var selectedTab = "home"
            var count = 3
        }

        struct CoordinatorLikeState: Equatable {
            var phase: Phase = .bootstrapping
            var isLoading = false
        }

        let old = CoordinatorLikeState(phase: .bootstrapping, isLoading: false)
        let new = CoordinatorLikeState(
            phase: .main(MainLikeState(selectedTab: "map", count: 9)),
            isLoading: false
        )

        let changes = FeatureLogStateDiff.changedFields(from: old, to: new)
        let phaseChange = changes.first(where: { $0.field == "phase" })
        XCTAssertEqual(phaseChange?.from, "bootstrapping")
        XCTAssertEqual(phaseChange?.to, "main")
        XCTAssertFalse((phaseChange?.to ?? "").contains("MainLikeState"))
        XCTAssertFalse((phaseChange?.to ?? "").contains("selectedTab"))

        let loggedOut = CoordinatorLikeState(
            phase: .loggedOut(AuthLikeState(isLoading: true, provider: "kakao")),
            isLoading: false
        )
        let toLoggedOut = FeatureLogStateDiff.changedFields(from: old, to: loggedOut)
        XCTAssertEqual(toLoggedOut.first(where: { $0.field == "phase" })?.to, "loggedOut")
        XCTAssertFalse((toLoggedOut.first(where: { $0.field == "phase" })?.to ?? "").contains("kakao"))
    }
}
