import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct NoticeDetailView: View {
    public let store: StoreOf<NoticeDetailFeature>

    public init(store: StoreOf<NoticeDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleSection

                Rectangle()
                    .fill(Color.bgSubtle)
                    .frame(height: 1)

                // 본문의 줄바꿈은 그대로 그린다. 주소가 섞여 와도 글자로만 둔다
                Text(store.notice.content)
                    .typography(.body1M)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
        }
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
    }

    // 제목과 날짜 사이 간격은 시안에 없어 목록 줄과 같은 6 으로 둔다
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.notice.title)
                .typography(.title2B)
                .foregroundStyle(Color.textPrimary)

            Text(store.notice.createdAt.shortDateText)
                .typography(.caption1R)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

#Preview("짧은 본문") {
    NavigationStack {
        NoticeDetailView(
            store: Store(initialState: NoticeDetailFeature.State(notice: Notice.mocks[0])) {
                NoticeDetailFeature()
            }
        )
    }
}

#Preview("긴 본문") {
    // 한 화면에 안 담겨야 스크롤이 도는 것을 보므로 가짜 공지보다 본문을 길게 둔다
    let notice = Notice(
        id: "preview-long",
        title: "서비스 점검 안내",
        content: """
        안녕하세요, 둘픽입니다.

        더 나은 서비스를 위해 아래와 같이 서버 점검을 진행합니다.

        · 점검 일시: 9월 3일 새벽 2시 ~ 4시 (2시간)
        · 점검 대상: 데이트 코스 추천, 장소 저장, 알림
        · 점검 영향: 점검 시간에는 앱 접속과 코스 만들기가 되지 않습니다

        점검 중에 만들던 코스는 저장되지 않을 수 있으니, 점검 시작 전에 저장해 주세요. \
        점검이 끝나면 앱을 껐다 켜 주시면 정상적으로 이용하실 수 있습니다.

        점검 시간은 작업 상황에 따라 앞당겨지거나 늦어질 수 있습니다. \
        변경되는 경우 공지사항을 통해 다시 알려드리겠습니다.

        이용에 불편을 드려 죄송합니다. 더 편한 둘픽으로 찾아뵙겠습니다. 감사합니다.
        """,
        createdAt: Date(timeIntervalSince1970: 1_788_397_200)
    )

    return NavigationStack {
        NoticeDetailView(
            store: Store(initialState: NoticeDetailFeature.State(notice: notice)) {
                NoticeDetailFeature()
            }
        )
    }
}
