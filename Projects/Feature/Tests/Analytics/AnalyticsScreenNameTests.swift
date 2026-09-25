@testable import Feature
import XCTest

@MainActor
final class AnalyticsScreenNameTests: XCTestCase {
    func test_시작단계는_스플래시다() {
        var state = RootFlowFeature.State()
        state.phase = .bootstrapping
        XCTAssertEqual(state.currentScreenName, .splash)
    }

    func test_홈탭의_빈_경로는_홈이다() {
        var tab = MainTabFeature.State()
        tab.selectedTab = .home
        XCTAssertEqual(tab.currentScreenName, .home)
    }

    func test_홈탭에서_코스날짜로_들어가면_이름이_바뀐다() {
        var tab = MainTabFeature.State()
        tab.selectedTab = .home
        tab.home.path = [.course]
        XCTAssertEqual(tab.currentScreenName, .courseDate)
    }

    func test_지도탭의_빈_경로는_지도다() {
        var tab = MainTabFeature.State()
        tab.selectedTab = .map
        XCTAssertEqual(tab.currentScreenName, .map)
    }

    func test_지도에서_장소검색으로_들어가면_이름이_바뀐다() {
        var tab = MainTabFeature.State()
        tab.selectedTab = .map
        tab.map.path = [.search]
        XCTAssertEqual(tab.currentScreenName, .placeSearch)
    }

    func test_탐색탭의_검색화면_이름은_Search다() {
        var tab = MainTabFeature.State()
        tab.selectedTab = .explore
        tab.explore.path = [.search]
        XCTAssertEqual(tab.currentScreenName, .search)
    }

    func test_마이탭의_연결관리_이름을_준다() {
        var tab = MainTabFeature.State()
        tab.selectedTab = .myPage
        tab.myPage.path = [.connection]
        XCTAssertEqual(tab.currentScreenName, .connectionManage)
    }

    func test_온보딩의_닉네임_화면_이름을_준다() {
        var state = OnboardingFlowFeature.State()
        state.path = [.nickname]
        XCTAssertEqual(state.currentScreenName, .nickname)
    }

    func test_지도에서_위에_있는_상세가_이름을_정한다() {
        var map = MapFlowFeature.State()
        map.topDetail = .place
        XCTAssertEqual(map.currentScreenName, .placeDetail)

        map.topDetail = .post
        XCTAssertEqual(map.currentScreenName, .postDetail)
    }

    func test_별칭시트는_상세보다_위다() {
        var map = MapFlowFeature.State()
        map.topDetail = .place
        map.isAliasPresented = true
        XCTAssertEqual(map.currentScreenName, .placeAlias)
    }

    func test_프로필수정_시트가_뜨면_그_이름이다() {
        var myPage = MyPageFlowFeature.State()
        myPage.myPage.isProfileEditPresented = true
        XCTAssertEqual(myPage.currentScreenName, .profileEdit)
    }

    func test_루트_장소가져오기_덮개_이름을_준다() {
        var state = RootFlowFeature.State()
        state.phase = .mainTab(MainTabFeature.State())
        guard let link = URL(string: "https://example.com") else {
            return XCTFail("테스트용 링크를 만들지 못했다")
        }
        state.placeImport = PlaceImportFeature.State(link: link)
        XCTAssertEqual(state.currentScreenName, .placeImport)
    }

    func test_루트_데이트유형_덮개_이름을_준다() {
        var onboarding = OnboardingFlowFeature.State()
        onboarding.dateType = DateTypeFeature.State()
        var state = RootFlowFeature.State()
        state.phase = .onboardingFlow(onboarding)
        XCTAssertEqual(state.currentScreenName, .dateType)
    }

    func test_탈퇴모달은_마이탭에서만_이름을_바꾼다() {
        var tab = MainTabFeature.State()
        tab.selectedTab = .home
        tab.myPage.myPage.isWithdrawModalPresented = true
        XCTAssertEqual(tab.currentScreenName, .home)

        tab.selectedTab = .myPage
        XCTAssertEqual(tab.currentScreenName, .withdraw)
    }

    func test_지도경로가_있으면_상세보다_경로가_이름을_정한다() {
        var map = MapFlowFeature.State()
        map.topDetail = .place
        map.path = [.search]
        XCTAssertEqual(map.currentScreenName, .placeSearch)
    }

    func test_마이탭의_공지_목록_이름을_준다() {
        var tab = MainTabFeature.State()
        tab.selectedTab = .myPage
        tab.myPage.path = [.noticeList]
        XCTAssertEqual(tab.currentScreenName, .noticeList)
    }

    func test_마이탭의_공지_상세_이름을_준다() {
        var tab = MainTabFeature.State()
        tab.selectedTab = .myPage
        tab.myPage.path = [.noticeList, .noticeDetail]
        XCTAssertEqual(tab.currentScreenName, .noticeDetail)
    }

    func test_공지_화면_이름은_대시보드_문자열과_같다() {
        XCTAssertEqual(AnalyticsScreenName.noticeList.rawValue, "NoticeList")
        XCTAssertEqual(AnalyticsScreenName.noticeDetail.rawValue, "NoticeDetail")
    }
}
