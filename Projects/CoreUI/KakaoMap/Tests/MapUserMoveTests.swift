@testable import CoreKakaoMap
import ThirdPartyUI
import XCTest

@MainActor
final class MapUserMoveTests: XCTestCase {
    func test_손으로_움직인_이동은_모두_사용자_손짓이다() {
        // 밀기 · 확대 · 축소 · 회전 · 기울이기 · 두 번 탭 전부다
        let userMoves: [MoveBy] = [
            .doubleTapZoomIn,
            .twoFingerTapZoomOut,
            .pan,
            .rotate,
            .zoom,
            .tilt,
            .longTapAndDrag,
            .rotateZoom,
            .oneFingerZoom,
        ]
        for move in userMoves {
            XCTAssertTrue(KakaoMapRepresentable.isUserMove(move), "MoveBy rawValue \(move.rawValue)")
        }
    }

    func test_앱이_옮긴_이동은_사용자_손짓이_아니다() {
        // 핀 탭 · 현위치 버튼 · 검색 결과로 옮기는 `animateCamera` 가 이 값으로 온다
        XCTAssertFalse(KakaoMapRepresentable.isUserMove(.notUserAction))
    }
}
