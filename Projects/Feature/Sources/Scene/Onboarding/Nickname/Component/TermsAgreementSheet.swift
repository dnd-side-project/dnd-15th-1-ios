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
                .padding(.horizontal, HeaderMetric.horizontalPadding)
                .padding(.top, HeaderMetric.topPadding)

            Spacer()
                .frame(height: TermsRowMetric.topMargin)

            termsRows

            Spacer()
                .frame(height: TermsRowMetric.bottomMargin)

            CTAContainer {
                AppButton("모두 동의하기", style: .dark, size: .xl, fullWidth: true) {
                    store.send(.termsAgreeButtonTapped)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HeaderMetric.lineSpacing) {
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

    // 체크 아이콘을 뺀 나머지 전부가 약관 내용 보기
    private func termsRow(_ terms: TermsType) -> some View {
        HStack(spacing: 0) {
            checkIcon

            Button {
                store.send(.termsDetailTapped(terms))
            } label: {
                HStack(spacing: 0) {
                    Text(terms.agreementTitle)
                        .typography(.body1M)
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image.arrowRight
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: TermsRowMetric.arrowIconSize, height: TermsRowMetric.arrowIconSize)
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: TermsRowMetric.arrowHitArea, height: TermsRowMetric.arrowHitArea)
                }
                .frame(height: TermsRowMetric.height)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(height: TermsRowMetric.height)
        .padding(.horizontal, TermsRowMetric.horizontalPadding)
    }

    // 필수 약관이라 동의는 "모두 동의하기" 하나로 끝난다. 아이콘은 항상 동의 상태를 보여준다
    private var checkIcon: some View {
        Image.checkTrue
            .renderingMode(.original)
            .resizable()
            .frame(width: CheckIconMetric.iconSize, height: CheckIconMetric.iconSize)
            .frame(width: CheckIconMetric.slotSize, height: CheckIconMetric.slotSize)
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

private enum HeaderMetric {
    static let horizontalPadding: CGFloat = 20
    static let topPadding: CGFloat = 12
    static let lineSpacing: CGFloat = 2
}

private enum TermsRowMetric {
    static let topMargin: CGFloat = 24
    static let bottomMargin: CGFloat = 24
    static let height: CGFloat = 44
    static let horizontalPadding: CGFloat = 8
    static let arrowIconSize: CGFloat = 20
    static let arrowHitArea: CGFloat = 44
}

private enum CheckIconMetric {
    static let iconSize: CGFloat = 24
    static let slotSize: CGFloat = 44
}

#if DEBUG
#Preview("약관 동의") {
    TermsAgreementSheet(
        store: Store(initialState: NicknameFeature.State()) {
            NicknameFeature()
        }
    )
}
#endif
