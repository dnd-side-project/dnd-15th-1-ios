import Domain
import SharedDesignSystem
import SwiftUI

struct SocialLoginButton: View {
    let provider: AuthProvider
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                icon
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: ButtonMetric.iconSize, height: ButtonMetric.iconSize)

                Group {
                    if isLoading {
                        ProgressView()
                            .tint(foreground)
                    } else {
                        Text(title)
                            .typography(.body1SB)
                            .foregroundStyle(foreground)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.trailing, ButtonMetric.iconSize)
            }
            .frame(maxWidth: .infinity)
            .frame(height: ButtonMetric.height)
            .padding(.horizontal, ButtonMetric.horizontalPadding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: ButtonMetric.cornerRadius))
            .overlay {
                if provider == .google {
                    RoundedRectangle(cornerRadius: ButtonMetric.cornerRadius)
                        .strokeBorder(Color.borderDefault, lineWidth: ButtonMetric.borderWidth)
                }
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isEnabled)
    }

    private var title: String {
        switch provider {
        case .apple: "애플로 로그인"
        case .kakao: "카카오로 로그인"
        case .google: "구글로 로그인"
        }
    }

    private var icon: Image {
        switch provider {
        case .apple: .socialApple
        case .kakao: .socialKakao
        case .google: .socialGoogle
        }
    }

    private var background: Color {
        switch provider {
        case .apple: .gray900
        case .kakao: Color(red: 254 / 255, green: 229 / 255, blue: 0)
        case .google: .commonWhite
        }
    }

    private var foreground: Color {
        switch provider {
        case .apple: .commonWhite
        case .kakao, .google: .gray900
        }
    }
}

private enum ButtonMetric {
    static let iconSize: CGFloat = 20
    static let height: CGFloat = 56
    static let horizontalPadding: CGFloat = 24
    static let cornerRadius: CGFloat = 12
    static let borderWidth: CGFloat = 1
}

#Preview("Default") {
    VStack(spacing: 8) {
        SocialLoginButton(
            provider: .apple,
            isLoading: false,
            isEnabled: true
        ) {}
        SocialLoginButton(
            provider: .kakao,
            isLoading: false,
            isEnabled: true
        ) {}
        SocialLoginButton(
            provider: .google,
            isLoading: false,
            isEnabled: true
        ) {}
    }
    .padding(20)
    .background(Color.commonWhite)
}

#Preview("Loading") {
    VStack(spacing: 8) {
        SocialLoginButton(
            provider: .apple,
            isLoading: true,
            isEnabled: false
        ) {}
        SocialLoginButton(
            provider: .kakao,
            isLoading: false,
            isEnabled: false
        ) {}
        SocialLoginButton(
            provider: .google,
            isLoading: false,
            isEnabled: false
        ) {}
    }
    .padding(20)
    .background(Color.commonWhite)
}
