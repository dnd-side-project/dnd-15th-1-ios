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
                AppButton(store.termsAgreeButtonTitle, style: .dark, size: .xl, fullWidth: true) {
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

    // 만 14세 동의는 약관 항목이 아니라 sheetTerms 밖이다. 시안대로 약관 셋 위에 둔다
    private var termsRows: some View {
        VStack(spacing: 0) {
            over14Row

            ForEach(NicknameFeature.sheetTerms) { terms in
                termsRow(terms)
            }
        }
    }

    // 체크 슬롯과 라벨이 동의를 켜고 끈다. 오른쪽 화살표만 약관 내용을 연다
    private func termsRow(_ terms: TermsType) -> some View {
        agreementRow(
            title: terms.agreementTitle,
            isOn: store.agreedTerms.contains(terms),
            onToggle: { store.send(.termsCheckTapped(terms)) },
            onOpenDetail: { store.send(.termsDetailTapped(terms)) }
        )
    }

    // 열 문서가 없어 화살표를 그리지 않는다. 줄 전체가 체크를 토글한다
    private var over14Row: some View {
        agreementRow(
            title: "만 14세 이상 이용 동의(필수)",
            isOn: store.isOver14Agreed,
            onToggle: { store.send(.over14CheckTapped) },
            onOpenDetail: nil
        )
    }

    private func agreementRow(
        title: String,
        isOn: Bool,
        onToggle: @escaping () -> Void,
        onOpenDetail: (() -> Void)?
    ) -> some View {
        HStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 0) {
                    checkIcon(isOn: isOn)

                    Text(title)
                        .typography(.body1M)
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: TermsRowMetric.height)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onOpenDetail {
                Button(action: onOpenDetail) {
                    Image.chevronRight
                        .renderingMode(.template)
                        .resizable()
                        .frame(
                            width: TermsRowMetric.arrowIconSize,
                            height: TermsRowMetric.arrowIconSize
                        )
                        .foregroundStyle(Color.textSecondary)
                        .frame(
                            width: TermsRowMetric.arrowHitArea,
                            height: TermsRowMetric.arrowHitArea
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: TermsRowMetric.height)
        .padding(.horizontal, TermsRowMetric.horizontalPadding)
    }

    private func checkIcon(isOn: Bool) -> some View {
        (isOn ? Image.checkFilled : Image.checkEmpty)
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
        case .marketing: "마케팅 수신 동의(선택)"
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
