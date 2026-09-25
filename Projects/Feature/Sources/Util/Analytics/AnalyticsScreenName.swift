import Foundation

/// 대시보드에 남길 화면 이름. 같은 화면은 어디서 들어왔든 한 이름이다
enum AnalyticsScreenName: String {
    case splash = "Splash"
    case appIntro = "AppIntro"
    case auth = "Auth"
    case nickname = "Nickname"
    case coupleConnect = "CoupleConnect"
    case coupleCodeInput = "CoupleCodeInput"
    case coupleComplete = "CoupleComplete"
    case dateType = "DateType"
    case home = "Home"
    case explore = "Explore"
    case map = "Map"
    case myPage = "MyPage"
    case search = "Search"
    case pastDateCourses = "PastDateCourses"
    case courseDate = "CourseDate"
    case coursePlacePick = "CoursePlacePick"
    case courseResult = "CourseResult"
    case courseEdit = "CourseEdit"
    case placeSearch = "PlaceSearch"
    case placeDetail = "PlaceDetail"
    case postDetail = "PostDetail"
    case placeAlias = "PlaceAlias"
    case placeImport = "PlaceImport"
    case connectionManage = "ConnectionManage"
    case profileEdit = "ProfileEdit"
    case withdraw = "Withdraw"
    case noticeList = "NoticeList"
    case noticeDetail = "NoticeDetail"
}

extension RootFlowFeature.State {
    var currentScreenName: AnalyticsScreenName {
        // 덮개가 맨 위다
        if onboardingFlow?.dateType != nil { return .dateType }
        if placeImport != nil { return .placeImport }

        switch phase {
        case .bootstrapping:
            return .splash
        case .appIntro:
            return .appIntro
        case .onboardingFlow:
            return onboardingFlow?.currentScreenName ?? .auth
        case .mainTab:
            return mainTab?.currentScreenName ?? .home
        }
    }
}

extension MainTabFeature.State {
    var currentScreenName: AnalyticsScreenName {
        switch selectedTab {
        case .home: return home.currentScreenName
        case .explore: return explore.currentScreenName
        case .map: return map.currentScreenName
        case .myPage: return myPage.currentScreenName
        }
    }
}

extension OnboardingFlowFeature.State {
    var currentScreenName: AnalyticsScreenName {
        switch path.last {
        case .none: return .auth
        case .nickname: return .nickname
        case .couple: return .coupleConnect
        case .coupleCodeInput: return .coupleCodeInput
        case .coupleComplete: return .coupleComplete
        }
    }
}

extension HomeFlowFeature.State {
    var currentScreenName: AnalyticsScreenName {
        switch path.last {
        case .none: return .home
        case .connect: return .coupleConnect
        case .codeInput: return .coupleCodeInput
        case .complete: return .coupleComplete
        case .pastDateCourses: return .pastDateCourses
        case .course: return .courseDate
        case .coursePlacePick, .coursePlaceAdd: return .coursePlacePick
        case .courseResult: return .courseResult
        case .courseEdit: return .courseEdit
        }
    }
}

extension ExploreFlowFeature.State {
    var currentScreenName: AnalyticsScreenName {
        switch path.last {
        case .none: return .explore
        case .search: return .search
        }
    }
}

extension MyPageFlowFeature.State {
    var currentScreenName: AnalyticsScreenName {
        if isWithdrawModalPresented { return .withdraw }
        // 프로필 수정은 바텀시트로 뜬다
        if myPage.isProfileEditPresented { return .profileEdit }

        switch path.last {
        case .none: return .myPage
        case .dateType: return .dateType
        case .connection: return .connectionManage
        case .noticeList: return .noticeList
        case .noticeDetail: return .noticeDetail
        case .connect: return .coupleConnect
        case .codeInput: return .coupleCodeInput
        case .complete: return .coupleComplete
        }
    }
}

extension MapFlowFeature.State {
    var currentScreenName: AnalyticsScreenName {
        // 별칭 시트가 상세 위에 뜬다
        if isAliasPresented { return .placeAlias }

        // 경로가 있으면 밀린 전체 화면이 위에 있다. 상세 시트는 경로가 비었을 때만 본다
        if path.isEmpty {
            switch topDetail {
            case .post: return .postDetail
            case .place: return .placeDetail
            case .none: break
            }
        }

        switch path.last {
        case .none: return .map
        case .postDetail: return .postDetail
        case .search: return .placeSearch
        case .course: return .courseDate
        case .coursePlacePick, .coursePlaceAdd: return .coursePlacePick
        case .courseResult: return .courseResult
        case .courseEdit: return .courseEdit
        }
    }
}
