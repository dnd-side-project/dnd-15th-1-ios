import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

private enum NoticeListMetric {
    static let skeletonRowCount = 3
    // 시안 값. 상단 띠 아랫변에서 그림 윗변까지
    static let emptyStateTopInset: CGFloat = 202
}

public struct NoticeListView: View {
    public let store: StoreOf<NoticeListFeature>

    public init(store: StoreOf<NoticeListFeature>) {
        self.store = store
    }

    public var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                BackToolbarItem { store.send(.backButtonTapped) }
                ToolbarItem(placement: .principal) {
                    Text("공지사항")
                        .typography(.body1SB)
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .background(Color.bgDefault)
            .onAppear { store.send(.onAppear) }
    }

    @ViewBuilder
    private var content: some View {
        if !store.hasLoaded {
            // 첫 로드 전에는 빈 화면이 스치지 않게 목록과 같은 모양을 깔아 둔다
            skeletonList
        } else if store.notices.isEmpty {
            emptyState
        } else {
            listContent
        }
    }

    private var skeletonList: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< NoticeListMetric.skeletonRowCount, id: \.self) { _ in
                NoticeRowSkeleton()

                divider
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.notices) { notice in
                    Button {
                        store.send(.noticeTapped(notice))
                    } label: {
                        NoticeRow(notice: notice)
                    }
                    .buttonStyle(.plain)
                    .onAppear { prefetchIfNeeded(notice) }

                    divider
                }

                if store.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
        }
    }

    // 끝에서 세 번째 줄이 보이면 미리 다음 페이지를 받아 스크롤이 끊기지 않게 한다
    private func prefetchIfNeeded(_ notice: Notice) {
        if notice.id == store.notices.suffix(3).first?.id {
            store.send(.reachedEnd)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.bgSubtle)
            .frame(height: 1)
    }

    private var emptyState: some View {
        EmptyStateView(
            image: .emptySchedule,
            title: "아직 올라온 공지사항이 없어요",
            alignment: .top
        )
        .padding(.top, NoticeListMetric.emptyStateTopInset)
    }
}

// 공지 한 줄. 높이가 80 으로 고정이라 제목은 한 줄로 자른다
private struct NoticeRow: View {
    let notice: Notice

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(notice.title)
                    .typography(.body1M)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(notice.createdAt.shortDateText)
                    .typography(.caption1R)
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer(minLength: 0)

            Image.chevronRight
                .renderingMode(.template)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.borderDefault)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(height: 80)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// NoticeRow 와 같은 높이·여백을 쓴다. 로드 전후로 줄이 밀리지 않게 맞춘 값이다
private struct NoticeRowSkeleton: View {
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                ShimmerBlock(cornerRadius: 4, baseColor: .gray300)
                    .frame(width: 180, height: 16)

                ShimmerBlock(cornerRadius: 4, baseColor: .gray300)
                    .frame(width: 60, height: 13)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(height: 80)
    }
}

#Preview("공지 세 건") {
    NavigationStack {
        NoticeListView(
            store: Store(initialState: NoticeListFeature.State()) {
                NoticeListFeature()
            } withDependencies: {
                $0.noticeClient = .mock
            }
        )
    }
}

#Preview("공지 없음") {
    NavigationStack {
        NoticeListView(
            store: Store(initialState: NoticeListFeature.State()) {
                NoticeListFeature()
            } withDependencies: {
                $0.noticeClient.notices = { _ in NoticePage(items: [], hasNext: false) }
            }
        )
    }
}

#Preview("불러오는 중") {
    NavigationStack {
        NoticeListView(
            store: Store(initialState: NoticeListFeature.State()) {
                NoticeListFeature()
            } withDependencies: {
                $0.noticeClient.notices = { _ in try await Task.never() }
            }
        )
    }
}

#Preview("다음 장 받는 중") {
    NavigationStack {
        NoticeListView(
            store: Store(
                initialState: NoticeListFeature.State(
                    notices: Notice.mocks,
                    page: 1,
                    hasNext: true,
                    hasLoaded: true,
                    isLoadingMore: true
                )
            ) {
                NoticeListFeature()
            }
        )
    }
}
