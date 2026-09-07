@testable import Feature
import XCTest

final class AnalyticsEventTests: XCTestCase {
    func test_이벤트_이름이_기획_표와_글자_그대로_같다() {
        XCTAssertEqual(AnalyticsEvent.appOpened.name, "app_opened")
        XCTAssertEqual(AnalyticsEvent.loginStarted.name, "login_started")
        XCTAssertEqual(AnalyticsEvent.coupleConnectStarted.name, "couple_connect_started")
        XCTAssertEqual(AnalyticsEvent.coupleConnected.name, "couple_connected")
        XCTAssertEqual(AnalyticsEvent.shareImportStarted.name, "share_import_started")
        XCTAssertEqual(AnalyticsEvent.courseCreateStarted(entryPoint: .homeBanner).name, "course_create_started")
        XCTAssertEqual(AnalyticsEvent.courseViewed(entryPoint: .homeBanner).name, "course_viewed")
        XCTAssertEqual(AnalyticsEvent.exploreViewed.name, "explore_viewed")
        XCTAssertEqual(AnalyticsEvent.savedPlaceDetailViewed.name, "saved_place_detail_viewed")
        XCTAssertEqual(AnalyticsEvent.mapViewed.name, "map_viewed")
        XCTAssertEqual(AnalyticsEvent.placeAddedToCourse.name, "place_added_to_course")
        XCTAssertEqual(AnalyticsEvent.courseCreated.name, "course_created")
        XCTAssertEqual(AnalyticsEvent.courseEditStarted.name, "course_edit_started")
        XCTAssertEqual(AnalyticsEvent.courseEdited.name, "course_edited")
        XCTAssertEqual(AnalyticsEvent.courseAlarmStarted(userID: "7").name, "course_alarm_started")
        XCTAssertEqual(AnalyticsEvent.myPageViewed.name, "mypage_viewed")
        XCTAssertEqual(AnalyticsEvent.preferenceSaved.name, "preference_saved")
        XCTAssertEqual(AnalyticsEvent.placeSaveModalViewed.name, "place_save_modal_viewed")
        XCTAssertEqual(AnalyticsEvent.placeSaveStarted(saveSource: .share).name, "place_save_started")
        XCTAssertEqual(AnalyticsEvent.placeSaveCompleted(saveSource: .inApp, userID: "7").name, "place_save_completed")
        XCTAssertEqual(AnalyticsEvent.courseScheduleCompleted.name, "course_schedule_completed")
        XCTAssertEqual(AnalyticsEvent.preferenceSetupStarted.name, "preference_setup_started")
    }

    func test_속성이_있는_이벤트만_값을_싣는다() {
        XCTAssertTrue(AnalyticsEvent.appOpened.properties.isEmpty)
        XCTAssertEqual(
            AnalyticsEvent.courseCreateStarted(entryPoint: .mapFloatingButton).properties,
            ["entry_point": .string("map_floating_button")]
        )
        XCTAssertEqual(
            AnalyticsEvent.courseViewed(entryPoint: .homeBanner).properties,
            ["entry_point": .string("home_banner")]
        )
        XCTAssertEqual(
            AnalyticsEvent.courseAlarmStarted(userID: "7").properties,
            ["user_id": .string("7")]
        )
        XCTAssertEqual(
            AnalyticsEvent.placeSaveStarted(saveSource: .share).properties,
            ["save_source": .string("share")]
        )
        XCTAssertEqual(
            AnalyticsEvent.placeSaveStarted(saveSource: .inApp).properties,
            ["save_source": .string("in_app")]
        )
        XCTAssertEqual(
            AnalyticsEvent.placeSaveCompleted(saveSource: .share, userID: "7").properties,
            [
                "save_source": .string("share"),
                "user_id": .string("7")
            ]
        )
        XCTAssertEqual(
            AnalyticsEvent.placeSaveCompleted(saveSource: .inApp, userID: "7").properties,
            [
                "save_source": .string("in_app"),
                "user_id": .string("7")
            ]
        )
        XCTAssertTrue(AnalyticsEvent.loginStarted.properties.isEmpty)
        XCTAssertTrue(AnalyticsEvent.exploreViewed.properties.isEmpty)
        XCTAssertTrue(AnalyticsEvent.placeSaveModalViewed.properties.isEmpty)
        XCTAssertTrue(AnalyticsEvent.courseScheduleCompleted.properties.isEmpty)
        XCTAssertTrue(AnalyticsEvent.preferenceSetupStarted.properties.isEmpty)
    }

    func test_세션이_없을_때_user_id_속성을_싣지_않는다() {
        XCTAssertEqual(
            AnalyticsEvent.courseAlarmStarted(userID: nil).properties,
            [:]
        )
        XCTAssertEqual(
            AnalyticsEvent.placeSaveCompleted(saveSource: .share, userID: nil).properties,
            ["save_source": .string("share")]
        )
        XCTAssertEqual(
            AnalyticsEvent.placeSaveCompleted(saveSource: .inApp, userID: nil).properties,
            ["save_source": .string("in_app")]
        )
    }
}
