import ComposableArchitecture
@testable import CoreKakaoMap
import Domain
@testable import Feature
import SharedUtils
import SwiftUI
import UIKit
import XCTest

/// 저장한 장소가 많으면 장소 고르기 목록이 화면 밖 행까지 다 만들어 앱이 멈춘다.
/// 사진이 있는 행은 가로 스크롤 하나를 만든다. 창에 띄운 뒤 그 수로 만들어진 행을 센다
@MainActor
final class CoursePlacePickListTests: XCTestCase {
    private let placeCount = 500
    private let photosPerPlace = 5
    /// iPhone 14 화면 안에는 사진 있는 행이 열 개도 안 들어간다. 미리 만드는 몇 행까지 넉넉히 둔다
    private let visibleRowLimit = 30

    override func setUp() async throws {
        // 화면에 카카오 지도가 있다. SDK 는 리소스 번들을 Bundle.main 에서만 찾아, 없으면 뷰를 만들다 죽는다.
        // 테스트 프로세스엔 그 번들이 없어 프리뷰가 쓰는 심으로 빌드 산출물의 번들을 붙인다
        // 심은 이 환경 변수가 있을 때만 붙는다. SwiftUI 도 이 값을 보고 프리뷰처럼 굴어 창에 안 그리므로 바로 지운다
        setenv("XCODE_RUNNING_FOR_PREVIEWS", "1", 1)
        KakaoMapPreviewBundleShim.activateIfNeeded()
        unsetenv("XCODE_RUNNING_FOR_PREVIEWS")
        // 심이 안 붙은 채 지도 뷰를 만들면 SDK 안에서 죽어 Feature 테스트 전체가 크래시로 끝난다. 이유를 남기고 여기서 멈춘다
        guard KakaoMapPreviewBundleShim.swizzleInstalled else {
            XCTFail(KakaoMapPreviewBundleShim.diagnostics.joined(separator: "\n"))
            throw KakaoBundleNotAttached()
        }
        // 지도 엔진은 켜지고 아무 키라 인증은 실패한다. 사진 줄만 세므로 상관없다
        KakaoMapBootstrap.run(appKey: "test")
    }

    func test_장소_500개면_화면에_보이는_행만_만든다() {
        var state = CourseFeature.State()
        state.places = (0 ..< placeCount).map(candidate(index:))
        state.loadState = .loaded
        let store = Store(initialState: state) {
            EmptyReducer<CourseFeature.State, CourseFeature.Action>()
        }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(rootView: CoursePlacePickView(store: store))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        guard waitUntilListRendered(in: window) else {
            XCTFail("목록이 그려지지 않았다")
            return
        }
        let builtRows = photoStrips(in: window).count

        XCTAssertLessThanOrEqual(
            builtRows,
            visibleRowLimit,
            "장소 \(placeCount)개 중 \(builtRows)개 행을 만들었다. 화면에 보이는 행만 만들어야 한다"
        )
    }

    private func candidate(index: Int) -> SavedPlace {
        let id = "place-\(index)"
        // 이름 조회가 안 되는 주소라 이미지가 채워지지 않는다
        let urls = (0 ..< photosPerPlace).compactMap { URL(string: "https://dulpick.invalid/\(id)/\($0).jpg") }
        return SavedPlace(
            place: Place(
                placeID: id,
                kakaoPlaceID: nil,
                name: "장소 \(index)",
                category: .food,
                address: "경기도 안산시 모모로 \(index)",
                roadAddress: nil,
                coordinate: Coordinate(latitude: 37.31, longitude: 126.90),
                bookmarkCount: nil,
                thumbnailURLs: urls
            ),
            ownership: .together,
            alias: nil,
            memo: nil,
            savedAt: nil
        )
    }

    /// 프로세스의 첫 SwiftUI 화면은 그려지기까지 오래 걸린다. 시간으로 기다리지 않고,
    /// 사진 줄이 하나라도 생긴 뒤 그 수가 세 번 연달아 같으면 다 그려진 것으로 본다
    private func waitUntilListRendered(in window: UIWindow, timeout: TimeInterval = 180) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var previous = -1
        var sameCount = 0
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            window.layoutIfNeeded()
            let count = photoStrips(in: window).count
            sameCount = count > 0 && count == previous ? sameCount + 1 : 0
            if sameCount == 2 { return true }
            previous = count
        }
        return false
    }

    /// 행의 사진 줄. 가로로만 움직이는 스크롤이라 세로 시트 스크롤과 갈린다
    private func photoStrips(in root: UIView) -> [UIScrollView] {
        var found: [UIScrollView] = []
        func visit(_ view: UIView) {
            if let scroll = view as? UIScrollView,
               scroll.contentSize.width > scroll.bounds.width + 1,
               scroll.contentSize.height <= scroll.bounds.height + 1 {
                found.append(scroll)
            }
            view.subviews.forEach(visit)
        }
        visit(root)
        return found
    }
}

private struct KakaoBundleNotAttached: Error {}
