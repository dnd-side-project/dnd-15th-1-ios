import CoreUserAnalytics
import Foundation

/// 코스 만들기와 코스 보기를 어디서 눌렀는지
enum AnalyticsEntryPoint: String {
    case homeBanner = "home_banner"
    case mapFloatingButton = "map_floating_button"
}

/// 장소를 밖에서 공유받아 저장했는지, 앱 안에서 저장했는지
enum AnalyticsSaveSource: String {
    case share
    case inApp = "in_app"
}

/// 믹스패널에 보내는 이벤트. 이름은 기획 표와 글자 그대로 같아야 한다.
///
/// 한 번 쌓인 이름은 못 바꾼다. 오타는 에러가 아니라 새 이벤트가 된다
enum AnalyticsEvent: Equatable {
    case appOpened
    case loginStarted
    case coupleConnectStarted
    case coupleConnected
    case shareImportStarted
    case courseCreateStarted(entryPoint: AnalyticsEntryPoint)
    case courseViewed(entryPoint: AnalyticsEntryPoint)
    case exploreViewed
    case savedPlaceDetailViewed
    case mapViewed
    case placeAddedToCourse
    case courseCreated
    case courseEditStarted
    case courseEdited
    case courseAlarmStarted(userID: String?)
    case myPageViewed
    case preferenceSaved
    case placeSaveModalViewed
    case placeSaveStarted(saveSource: AnalyticsSaveSource)
    case placeSaveCompleted(saveSource: AnalyticsSaveSource, userID: String?)
    case courseScheduleCompleted
    case preferenceSetupStarted

    var name: String {
        switch self {
        case .appOpened: "app_opened"
        case .loginStarted: "login_started"
        case .coupleConnectStarted: "couple_connect_started"
        case .coupleConnected: "couple_connected"
        case .shareImportStarted: "share_import_started"
        case .courseCreateStarted: "course_create_started"
        case .courseViewed: "course_viewed"
        case .exploreViewed: "explore_viewed"
        case .savedPlaceDetailViewed: "saved_place_detail_viewed"
        case .mapViewed: "map_viewed"
        case .placeAddedToCourse: "place_added_to_course"
        case .courseCreated: "course_created"
        case .courseEditStarted: "course_edit_started"
        case .courseEdited: "course_edited"
        case .courseAlarmStarted: "course_alarm_started"
        case .myPageViewed: "mypage_viewed"
        case .preferenceSaved: "preference_saved"
        case .placeSaveModalViewed: "place_save_modal_viewed"
        case .placeSaveStarted: "place_save_started"
        case .placeSaveCompleted: "place_save_completed"
        case .courseScheduleCompleted: "course_schedule_completed"
        case .preferenceSetupStarted: "preference_setup_started"
        }
    }

    var properties: [String: AnalyticsValue] {
        switch self {
        case let .courseCreateStarted(entryPoint), let .courseViewed(entryPoint):
            return ["entry_point": .string(entryPoint.rawValue)]
        case let .courseAlarmStarted(userID):
            guard let userID else { return [:] }
            return ["user_id": .string(userID)]
        case let .placeSaveStarted(saveSource):
            return ["save_source": .string(saveSource.rawValue)]
        case let .placeSaveCompleted(saveSource, userID):
            var properties: [String: AnalyticsValue] = [
                "save_source": .string(saveSource.rawValue)
            ]
            if let userID {
                properties["user_id"] = .string(userID)
            }
            return properties
        default:
            return [:]
        }
    }
}
