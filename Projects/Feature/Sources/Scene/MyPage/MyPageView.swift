import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct MyPageView: View {
    @Bindable public var store: StoreOf<MyPageFeature>
    @Environment(\.openURL) private var openURL

    // 피드백 수신 서비스 메일
    private static let feedbackEmail = "dulpick.co@gmail.com"

    public init(store: StoreOf<MyPageFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                profileSection.padding(.bottom, 20)
                securityCard.padding(.bottom, 30)
                notificationCard.padding(.bottom, 30)
                inquiryCard.padding(.bottom, 20)
                footer.padding(.vertical, 10)
                withdrawButton.padding(.vertical, 10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .background(.bgSubtle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("마이페이지")
                    .typography(.title2B)
                    .foregroundStyle(Color.gray900)
            }
        }
        .toolbarRole(.editor)
        .sheet(item: presentedTermsBinding) { terms in
            if let url = terms.url {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .task {
            store.send(.onAppear)
        }
    }

    private var presentedTermsBinding: Binding<TermsType?> {
        Binding(
            get: { store.presentedTerms },
            set: { newValue in
                if newValue == nil {
                    store.send(.dismissTerms)
                }
            }
        )
    }

    private var profileSection: some View {
        VStack(spacing: 8) {
            profileImage
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())

            Text(store.nickname)
                .typography(.headline)
                .foregroundStyle(.textPrimary)

            AppButton("프로필 수정", style: .outlined, size: .sm) {
                store.send(.profileEditTapped)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var securityCard: some View {
        card("개인/보안") {
            navRow("나의 데이트 유형", edge: .first) { store.send(.dateTypeTapped) }
            divider
            navRow("연결 관리") { store.send(.connectionTapped) }
            divider
            navRow("로그아웃", edge: .last) { store.send(.logoutButtonTapped) }
        }
    }

    private var notificationCard: some View {
        card("알림 설정") {
            toggleRow("콘텐츠 저장 알림", isOn: $store.savedContentAlarmOn)
            divider
            toggleRow("데이트 일정 알림", isOn: $store.dateScheduleAlarmOn)
            divider
            toggleRow("마케팅 정보 알림", isOn: $store.marketingAlarmOn)
        }
    }

    private var inquiryCard: some View {
        card("문의하기") {
            navRow("서비스 피드백하기", edge: .only) { sendFeedbackMail() }
        }
    }

    // 기본 메일 앱으로 서비스 메일 작성 화면을 연다
    private func sendFeedbackMail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.feedbackEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "둘픽 서비스 피드백")]
        guard let url = components.url else { return }
        openURL(url)
    }

    private var footer: some View {
        TermsLinksView { terms in
            store.send(.termsLinkTapped(terms))
        }
        .frame(maxWidth: .infinity)
    }

    private var withdrawButton: some View {
        Button("회원탈퇴") { store.send(.withdrawTapped) }
            .typography(.caption1R)
            .foregroundStyle(.statusError)
            .frame(maxWidth: .infinity)
    }

    // 아이콘 ID 를 프로필 이미지로. profile1 은 selected 변형을 쓰고, 미매핑 값도 여기로 떨어진다
    private var profileImage: Image {
        switch store.iconID {
        case 2: .profile2
        case 3: .profile3
        case 4: .profile4
        case 5: .profile5
        default: .profile1Selected
        }
    }
}

// MARK: - 공통 카드·행

private extension MyPageView {
    // 회색 배경 위에 올리는 흰 카드. 섹션 제목은 카드 바깥 위
    func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .typography(.body1SB)
                .foregroundStyle(.textPrimary)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 20)
            .background(.commonWhite)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // 카드 안 행 위치. 첫 행 top·마지막 행 bottom 은 20, 나머지 모서리는 14
    enum RowEdge {
        case first, middle, last, only

        var top: CGFloat { self == .first || self == .only ? 20 : 14 }
        var bottom: CGFloat { self == .last || self == .only ? 20 : 14 }
    }

    func navRow(_ title: String, edge: RowEdge = .middle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .typography(.body2M)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Image.arrowRight
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.top, edge.top)
            .padding(.bottom, edge.bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .typography(.body2M)
                .foregroundStyle(.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.textPrimary)
        }
        .padding(.vertical, 14)
    }

    var divider: some View {
        Rectangle()
            .fill(.bgSubtle)
            .frame(height: 1)
    }
}
