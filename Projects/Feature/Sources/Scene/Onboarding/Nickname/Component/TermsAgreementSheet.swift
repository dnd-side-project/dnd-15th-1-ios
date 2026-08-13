import SharedDesignSystem
import SwiftUI
import ThirdParty

// NicknameView 가 .bottomSheet(isDismissable: false) 로 올리는 내용 뷰
// 높이는 내용이 정한다. 핸들과 하단 safe area 는 BottomSheet 가 따로 그린다
struct TermsAgreementSheet: View {
    let store: StoreOf<NicknameFeature>

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Spacer()
                .frame(height: 24)

            termsRows

            Spacer()
                .frame(height: 24)

            CTAContainer {
                AppButton("모두 동의하기", style: .dark, size: .xl, fullWidth: true) {
                    store.send(.termsAgreeButtonTapped)
                }
                .disabled(!store.isTermsAgreeEnabled)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("잠깐만요!")
                .typography(.title2B)
                .foregroundStyle(Color.gray900)

            Text("서비스 이용을 위해 약관 동의가 필요해요")
                .typography(.body1M)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var termsRows: some View {
        VStack(spacing: 0) {
            ForEach(NicknameFeature.requiredTerms) { terms in
                termsRow(terms)
            }
        }
    }

    private func termsRow(_ terms: TermsType) -> some View {
        HStack(spacing: 0) {
            Button {
                store.send(.termsToggled(terms))
            } label: {
                checkIcon(isAgreed: store.agreedTerms.contains(terms))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(terms.agreementTitle)
                .typography(.body1M)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                store.send(.termsDetailTapped(terms))
            } label: {
                Image.arrowRight
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 44)
        .padding(.horizontal, 8)
    }

    private func checkIcon(isAgreed: Bool) -> some View {
        // checkTrue 는 primaryPink 원 + 흰 체크, checkFalse 는 borderDefault 테두리 원이라 시안 그대로다
        (isAgreed ? Image.checkTrue : Image.checkFalse)
            .renderingMode(.original)
            .resizable()
            .frame(width: 24, height: 24)
    }
}

// TermsType.title 은 "이용약관" 이라 시안 문구와 달라 이 시트 전용 표시 문구를 따로 둔다
private extension TermsType {
    var agreementTitle: String {
        switch self {
        case .service: "서비스 이용약관(필수)"
        case .privacy: "개인정보수집 및 이용(필수)"
        }
    }
}

#if DEBUG
#Preview("미동의") {
    TermsAgreementSheet(
        store: Store(initialState: NicknameFeature.State()) {
            NicknameFeature()
        }
    )
}

#Preview("모두 동의") {
    TermsAgreementSheet(
        store: Store(
            initialState: NicknameFeature.State(agreedTerms: [.service, .privacy])
        ) {
            NicknameFeature()
        }
    )
}
#endif
