import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct HomeView: View {
    @Bindable public var store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        scrollContent
            .navigationDestination(for: HomeFeature.HomeRoute.self) { route in
                destination(route)
            }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                topSection
                contentSheet
            }
        }
        .background {
            VStack(spacing: 0) {
                Color.gray900
                Color.bgDefault
            }
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { store.send(.onAppear) }
    }

    @ViewBuilder
    private func destination(_ route: HomeFeature.HomeRoute) -> some View {
        switch route {
        case .connect, .codeInput, .complete:
            coupleDestination(route)
        case .pastDateCourses:
            // 검색 화면과 동일하게 뷰를 직접 렌더하고 tabBar 숨김은 그 뷰가 스스로 처리한다
            if let pastStore {
                PastDateCoursesView(store: pastStore)
            }
        case .course:
            // 코스 두 화면도 tabBar 숨김을 스스로 하므로 직접 렌더한다
            if let courseStore {
                CourseDateView(store: courseStore)
            }
        case .coursePlacePick:
            if let courseStore {
                CoursePlacePickView(store: courseStore)
            }
        }
    }

    // 커플 세 화면은 같은 스토어를 공유. push 동안 하단탭은 숨긴다
    @ViewBuilder
    private func coupleDestination(_ route: HomeFeature.HomeRoute) -> some View {
        if let coupleStore {
            Group {
                switch route {
                case .codeInput:
                    CoupleCodeInputView(store: coupleStore)
                case .complete:
                    CoupleCompleteView(store: coupleStore)
                default:
                    CoupleConnectView(store: coupleStore)
                }
            }
            .toolbar(.hidden, for: .tabBar)
        }
    }

    private var coupleStore: StoreOf<CoupleConnectFeature>? {
        store.scope(state: \.couple, action: \.couple)
    }

    private var pastStore: StoreOf<PastDateCoursesFeature>? {
        store.scope(state: \.pastDateCourses, action: \.pastDateCourses)
    }

    private var courseStore: StoreOf<CourseFeature>? {
        store.scope(state: \.course, action: \.course)
    }

    private var topSection: some View {
        VStack(spacing: 0) {
            HomeHeader(
                nickname: store.nickname,
                partnerName: store.partnerName,
                calendarTapped: {
                    // 로딩 중엔 달력 동작을 막는다
                    guard store.didLoadSummary else { return }
                    store.send(.calendarTapped)
                }
            )

            Group {
                if store.didLoadSummary {
                    HomeBanner(
                        isConnected: store.isConnected,
                        upcomingSchedule: store.upcomingSchedule,
                        connectTapped: { store.send(.connectFlowRequested) },
                        createCourseTapped: { store.send(.courseFlowRequested) },
                        bannerTapped: {}
                    )
                } else {
                    skeletonBanner
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color.gray900.ignoresSafeArea(edges: .top))
    }

    private var contentSheet: some View {
        VStack(alignment: .leading, spacing: 60) {
            recommendationSection

            if store.showsPastSchedules {
                pastScheduleSection
            }

            savedPlaceSection
        }
        .padding(.top, 40)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity)
        .background(Color.bgDefault)
        .clipShape(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
        )
        .background(alignment: .top) {
            Color.gray900
                .frame(height: 24)
        }
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            recommendationTitle

            if store.recommendations.isEmpty {
                recommendationSkeletonRow
            } else {
                recommendationScroll
            }
        }
    }

    private var recommendationTitle: some View {
        (
            Text("\(store.nickname)님을 위한 ")
                .foregroundColor(Color.textPrimary)
                + Text("장소 추천")
                .foregroundColor(Color.primaryPink)
        )
        .typography(.title2B)
        // 닉네임 로드 전 빈 값이 그려졌다 리플로우되는 걸 막고, 자리만 잡아둔다
        .opacity(store.didLoadSummary ? 1 : 0)
        .padding(.horizontal, 20)
    }

    private var recommendationScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(store.recommendations) { content in
                    Button {
                        store.send(.recommendationTapped(content.id))
                    } label: {
                        ContentCard(content: content)
                            .frame(width: 170)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var pastScheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("우리의 지난 데이트 일정")
                .typography(.title2B)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.visiblePastSchedules) { schedule in
                        DateScheduleCard(schedule: schedule)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var savedPlaceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            savedPlaceHeader
                .padding(.horizontal, 20)

            savedPlaceContent
        }
    }

    private var savedPlaceHeader: some View {
        HStack {
            Text("최근 저장된 장소")
                .typography(.title2B)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            if !store.visibleSavedPlaces.isEmpty {
                Button {
                    store.send(.savedPlacesSeeAllTapped)
                } label: {
                    HStack(spacing: 2) {
                        Text("전체보기")
                            .typography(.body1M)
                        Image.arrowRight
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    .foregroundStyle(Color.textTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var savedPlaceContent: some View {
        if !store.didLoadSaved {
            // 로드 전엔 빈 상태·리스트를 모르니 행 시머로 자리를 잡는다
            VStack(spacing: 8) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    savedPlaceSkeletonRow
                }
            }
            .padding(.horizontal, 20)
        } else if store.visibleSavedPlaces.isEmpty {
            EmptyStateView(
                image: .placeEmpty,
                title: "최근 저장된 장소가 없어요!",
                message: "장소를 저장해주세요"
            )
            .padding(.top, 40)
        } else {
            VStack(spacing: 8) {
                ForEach(store.visibleSavedPlaces) { place in
                    Button {
                        store.send(.savedPlaceTapped(place.id))
                    } label: {
                        SavedPlaceRow(place: place)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 첫 로딩 스켈레톤

private extension HomeView {
    // 연결 배너 크기로 고정. 요약이 오면 실제 배너로 교체된다
    var skeletonBanner: some View {
        ShimmerBlock(cornerRadius: 16, baseColor: .gray700)
            .frame(height: HomeSkeletonMetric.bannerHeight)
            .padding(.horizontal, 20)
    }

    // 추천은 항상 데이터가 있어 비어있으면 로딩. 카드 폭 170으로 실제와 맞춘다
    var recommendationSkeletonRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    ContentCardSkeleton()
                        .frame(width: 170)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // SavedPlaceRow 와 같은 높이·패딩. 아이콘·이름 자리를 시머로 채운다
    var savedPlaceSkeletonRow: some View {
        HStack(spacing: 8) {
            ShimmerBlock(cornerRadius: 4, baseColor: .gray300)
                .frame(width: 24, height: 24)

            ShimmerBlock(cornerRadius: 4, baseColor: .gray300)
                .frame(width: 140, height: 16)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private enum HomeSkeletonMetric {
    // 연결(짧은) 배너 이미지 높이에 맞춘 스켈레톤 배너 높이
    static let bannerHeight: CGFloat = 110
}
