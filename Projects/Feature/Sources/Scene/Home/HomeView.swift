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
            .navigationDestination(for: HomeFeature.CoupleRoute.self) { route in
                coupleDestination(route)
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

    // 세 화면 모두 같은 couple 스토어를 받고 Route 로 무엇을 그릴지만 가른다. push 동안 하단탭은 숨긴다
    @ViewBuilder
    private func coupleDestination(_ route: HomeFeature.CoupleRoute) -> some View {
        if let coupleStore {
            Group {
                switch route {
                case .connect:
                    CoupleConnectView(store: coupleStore)
                case .codeInput:
                    CoupleCodeInputView(store: coupleStore)
                case .complete:
                    CoupleCompleteView(store: coupleStore)
                }
            }
            .toolbar(.hidden, for: .tabBar)
        }
    }

    private var coupleStore: StoreOf<CoupleConnectFeature>? {
        store.scope(state: \.couple, action: \.couple)
    }

    private var topSection: some View {
        VStack(spacing: 0) {
            HomeHeader(
                nickname: store.nickname,
                partnerName: store.partnerName,
                calendarTapped: { store.send(.connectFlowRequested) }
            )

            HomeBanner(
                isConnected: store.isConnected,
                upcomingSchedule: store.upcomingSchedule,
                connectTapped: { store.send(.connectFlowRequested) },
                bannerTapped: {}
            )
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
            (
                Text("\(store.nickname)님을 위한 ")
                    .foregroundColor(Color.textPrimary)
                    + Text("장소 추천")
                    .foregroundColor(Color.primaryPink)
            )
            .typography(.title2B)
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(store.recommendations) { content in
                        ContentCard(content: content)
                            .frame(width: 170)
                    }
                }
                .padding(.horizontal, 20)
            }
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
        if store.visibleSavedPlaces.isEmpty {
            EmptyStateView(
                image: .placeEmpty,
                title: "최근 저장된 장소가 없어요!",
                message: "장소를 저장해주세요"
            )
            .padding(.top, 40)
        } else {
            VStack(spacing: 8) {
                ForEach(store.visibleSavedPlaces) { place in
                    SavedPlaceRow(place: place)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
