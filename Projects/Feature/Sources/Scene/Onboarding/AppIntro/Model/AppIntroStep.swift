import Foundation
import SharedDesignSystem
import SwiftUI

/// App intro 화면의 단계.
public enum AppIntroStep: Int, CaseIterable, Identifiable, Equatable, Sendable {
    case share = 0
    case save = 1
    case plan = 2

    public var id: Int { rawValue }
}

public extension AppIntroStep {
    var title: String {
        switch self {
        case .share:
            "인스타에서 공유 버튼을\n통해 둘픽에 저장해요"
        case .save:
            "둘픽에 함께 저장한\n장소를 모아볼 수 있어요"
        case .plan:
            "저장한 장소를 함께\n데이트 코스로 계획해요"
        }
    }

    var image: Image {
        switch self {
        case .share:
            .appIntroShare
        case .save:
            .appIntroSave
        case .plan:
            .appIntroPlan
        }
    }

    /// 단계별 title/image 로 전체 페이지 목록을 조립한다.
    static var pages: [AppIntroPage] {
        allCases.map { step in
            AppIntroPage(title: step.title, image: step.image)
        }
    }
}
