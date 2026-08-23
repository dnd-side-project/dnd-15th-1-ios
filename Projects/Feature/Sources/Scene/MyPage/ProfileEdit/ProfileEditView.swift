import SharedDesignSystem
import SwiftUI
import ThirdParty
import UIKit

public struct ProfileEditView: View {
    static let heightRatio: CGFloat = 0.65

    @Bindable var store: StoreOf<ProfileEditFeature>
    @State private var isNicknameFocused = false

    public init(store: StoreOf<ProfileEditFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            preview
            iconRow
            divider
            nicknameSection
            Spacer(minLength: 0)
            doneButton
        }
        .padding(.horizontal, 20)
        .frame(height: UIScreen.main.bounds.height * Self.heightRatio)
    }

    private var header: some View {
        ZStack {
            Text("프로필 수정")
                .typography(.body1SB)
                .foregroundStyle(.textPrimary)
            HStack {
                Button { store.send(.closeTapped) } label: {
                    Image.x
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.textPrimary)
                }
                Spacer()
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 32)
    }

    private var preview: some View {
        profileImage(for: store.selectedIconID)
            .resizable()
            .scaledToFill()
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .padding(.bottom, 20)
    }

    private var iconRow: some View {
        HStack(spacing: 12) {
            ForEach(ProfileEditFeature.iconIDs, id: \.self) { id in
                iconButton(id)
            }
        }
        .padding(.bottom, 20)
    }

    private func iconButton(_ id: Int) -> some View {
        Button { store.send(.iconSelected(id)) } label: {
            profileImage(for: id)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .overlay {
                    if store.selectedIconID == id {
                        Circle().stroke(.primaryPink, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(.borderWeak)
            .frame(height: 1)
            .padding(.bottom, 20)
    }

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("닉네임")
                .typography(.body1M)
                .foregroundStyle(.textPrimary)

            AppTextField(
                text: $store.nickname,
                placeholder: "닉네임",
                size: .large,
                style: .filled,
                errorMessage: store.lengthError,
                sanitize: ProfileEditFeature.sanitizedNickname,
                isFocused: $isNicknameFocused,
                onSubmit: { isNicknameFocused = false }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var doneButton: some View {
        AppButton("완료", style: .dark, size: .xl, fullWidth: true) {
            isNicknameFocused = false
            store.send(.doneTapped)
        }
        .disabled(!store.isDoneEnabled)
        .padding(.bottom, 20)
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
