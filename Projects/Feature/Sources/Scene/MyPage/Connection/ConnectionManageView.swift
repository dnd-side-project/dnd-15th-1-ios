import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct ConnectionManageView: View {
    private static let profileSize: CGFloat = 100
    private static let strokeWidth: CGFloat = 4
    private static let profileInset: CGFloat = 24
    private static let cardInset: CGFloat = 20
    private static let heartSize: CGFloat = 44
    private static let profileGap: CGFloat = 20
    // 세로 중앙에서 위로 올리는 양 (시안 상단 140 · 하단 248 의 절반 차)
    private static let centerOffsetUp: CGFloat = 54

    @Bindable var store: StoreOf<ConnectionManageFeature>

    public init(store: StoreOf<ConnectionManageFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 카드+이름은 세로 중앙에서 일정만큼 위로 올린다
            VStack(spacing: 0) {
                coupleCard
                namesRow
                    .padding(.top, 12)
            }
            .offset(y: -Self.centerOffsetUp)

            Spacer()

            CTAContainer {
                AppButton("커플 연결 끊기", style: .dark, size: .xl, fullWidth: true) {
                    store.send(.disconnectTapped)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.bgDefault)
        .toast(item: toastBinding)
        .modal(isPresented: disconnectModalBinding) {
            ModalContent(
                title: "잠깐!\n정말 커플 연결을 끊으시겠어요?",
                content: "지금까지 저장된 데이터가 모두 날아가요",
                image: .disconnect,
                primaryTitle: "연결 끊기",
                primaryAction: { store.send(.disconnectConfirmed) },
                secondaryTitle: "취소",
                secondaryAction: { store.send(.dismissDisconnectModal) }
            )
        }
        .task { store.send(.onAppear) }
    }

    private var disconnectModalBinding: Binding<Bool> {
        Binding(
            get: { store.isDisconnectModalPresented },
            set: { isPresented in
                if !isPresented {
                    store.send(.dismissDisconnectModal)
                }
            }
        )
    }

    private var toastBinding: Binding<ToastState?> {
        Binding(
            get: { store.toast },
            set: { newValue in
                if newValue == nil {
                    store.send(.dismissToast)
                }
            }
        )
    }

    private var coupleCard: some View {
        Image.connectionManage
            .resizable()
            .scaledToFit()
            .overlay(alignment: .topLeading) { badge }
            .overlay(alignment: .bottom) {
                profilesRow.padding(.bottom, -2)
            }
            .padding(.horizontal, Self.cardInset)
    }

    private var badge: some View {
        Text("둘픽에서 함께한 지 \(store.daysTogether ?? 0)일째")
            .typography(.body2SB)
            .foregroundStyle(Color.primaryPink)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.commonWhite.opacity(0.9)))
            .padding(18)
    }

    private var profilesRow: some View {
        HStack(spacing: 0) {
            Spacer()
            profileCircle(store.me?.iconID)
                .padding(.trailing, Self.profileGap)
            heart
            profileCircle(store.partner?.iconID)
                .padding(.leading, Self.profileGap)
            Spacer()
        }
        .padding(.horizontal, Self.profileInset)
    }

    private var heart: some View {
        Image.heartWithStroke
            .resizable()
            .scaledToFit()
            .frame(width: Self.heartSize, height: Self.heartSize)
    }

    private func profileCircle(_ iconID: Int?) -> some View {
        profileImage(for: iconID ?? 1)
            .resizable()
            .scaledToFill()
            .frame(width: Self.profileSize, height: Self.profileSize)
            .clipShape(Circle())
            .background {
                Circle()
                    .fill(Color.commonWhite)
                    .padding(-Self.strokeWidth)
            }
    }

    // 프로필과 동일한 가로 배치라 이름이 각 프로필 정중앙 아래에 온다
    private var namesRow: some View {
        HStack(spacing: 0) {
            Spacer()
            Text(store.me?.nickname ?? "")
                .frame(width: Self.profileSize)
                .padding(.trailing, Self.profileGap)
            Spacer().frame(width: Self.heartSize)
            Text(store.partner?.nickname ?? "")
                .frame(width: Self.profileSize)
                .padding(.leading, Self.profileGap)
            Spacer()
        }
        .typography(.headline)
        .foregroundStyle(Color.textPrimary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, Self.cardInset + Self.profileInset)
    }

    // 아이콘 ID 를 프로필 이미지로. 미매핑 값은 기본 프로필로
    private func profileImage(for id: Int) -> Image {
        switch id {
        case 2: .profile2
        case 3: .profile3
        case 4: .profile4
        case 5: .profile5
        default: .profile1
        }
    }
}
