//
//  SocialLoginButton.swift
//  AppFoundation / AuthKit
//
//  소셜 로그인 버튼 (SwiftUI). provider별 타입을 나누지 않고 `setProvider` 로
//  브랜드 렌더링(색·로고·문구)을 전환한다. 설정값은 전부 내부 변수로 저장하고
//  `set~` 빌더 모디파이어로 수정한다.
//
//  사용 예:
//      SocialLoginButton { viewModel.signInKakao() }
//          .setProvider(.kakao)
//          .setCornerRadius(16)
//          .setIsLoading($isLoading)
//

import SwiftUI

public struct SocialLoginButton: View {

    // MARK: - 설정값 (set 모디파이어로 수정)

    private var provider: SocialProvider = .apple
    private var cornerRadius: CGFloat = 12
    private var height: CGFloat = 52
    private var isLoading: Binding<Bool> = .constant(false)
    private var appleStyle: AppleLoginStyle = .black

    private let action: @MainActor () -> Void

    public init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    // MARK: - set 모디파이어 (빌더)

    /// 브랜드 렌더링(색·로고·문구) 전환. 기본 `.apple`.
    public func setProvider(_ provider: SocialProvider) -> Self {
        copy { $0.provider = provider }
    }

    /// 모서리 반경. 기본 12.
    public func setCornerRadius(_ radius: CGFloat) -> Self {
        copy { $0.cornerRadius = radius }
    }

    /// 버튼 높이. 기본 52.
    public func setHeight(_ height: CGFloat) -> Self {
        copy { $0.height = height }
    }

    /// 로딩 상태 바인딩 — true 면 스피너 표시 + 터치 비활성.
    public func setIsLoading(_ isLoading: Binding<Bool>) -> Self {
        copy { $0.isLoading = isLoading }
    }

    /// Apple 버튼 HIG 스타일(.black/.white/.whiteOutline). 기본 `.black`.
    /// provider 가 `.apple` 이 아닐 때는 무시된다.
    public func setAppleStyle(_ style: AppleLoginStyle) -> Self {
        copy { $0.appleStyle = style }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var copied = self
        mutate(&copied)
        return copied
    }

    // MARK: - Body

    public var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: 8) {
                    logo
                        .frame(width: 18, height: 18)
                    Text(titleKey, bundle: .module)
                        .font(.system(size: 16, weight: .semibold))
                }
                .opacity(isLoading.wrappedValue ? 0 : 1)

                if isLoading.wrappedValue {
                    ProgressView()
                        .tint(foreground)
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(background, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(border, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading.wrappedValue)
    }

    // MARK: - 브랜드 렌더링

    private var titleKey: LocalizedStringKey {
        switch provider {
        case .apple: "social.login.apple"
        case .google: "social.login.google"
        case .kakao: "social.login.kakao"
        }
    }

    private var foreground: Color {
        switch provider {
        case .apple:
            appleStyle == .black ? .white : .black
        case .google:
            Color(uiColor: SocialLoginLogo.BrandColor.googleForeground)
        case .kakao:
            Color(uiColor: SocialLoginLogo.BrandColor.kakaoForeground)
        }
    }

    private var background: Color {
        switch provider {
        case .apple:
            appleStyle == .black ? .black : .white
        case .google:
            .white
        case .kakao:
            Color(uiColor: SocialLoginLogo.BrandColor.kakaoBackground)
        }
    }

    private var border: Color? {
        switch provider {
        case .apple:
            appleStyle == .whiteOutline
                ? Color(uiColor: SocialLoginLogo.BrandColor.appleOutlineBorder)
                : nil
        case .google:
            Color(uiColor: SocialLoginLogo.BrandColor.googleBorder)
        case .kakao:
            nil
        }
    }

    @ViewBuilder
    private var logo: some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 17, weight: .medium))
                // 로고 하단이 살짝 무거워 보정
                .offset(y: -1)

        case .kakao:
            KakaoSymbolShape()
                .fill(foreground)

        case .google:
            GoogleLogoView()
        }
    }
}

// MARK: - 로고 뷰 (CGPath 공유 정의를 SwiftUI 로)

private struct KakaoSymbolShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(SocialLoginLogo.kakaoBubblePath(in: rect))
    }
}

private struct GoogleLogoView: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            for segment in SocialLoginLogo.googleSegments(in: rect) {
                context.fill(Path(segment.path), with: .color(Color(uiColor: segment.color)))
            }
        }
    }
}

// MARK: - Preview

#Preview("Providers") {
    VStack(spacing: 12) {
        SocialLoginButton {}
            .setProvider(.apple)
        SocialLoginButton {}
            .setProvider(.kakao)
        SocialLoginButton {}
            .setProvider(.google)
        SocialLoginButton {}
            .setProvider(.apple)
            .setAppleStyle(.whiteOutline)
        SocialLoginButton {}
            .setProvider(.kakao)
            .setIsLoading(.constant(true))
        SocialLoginButton {}
            .setProvider(.google)
            .setCornerRadius(26)
            .setHeight(56)
    }
    .padding(24)
    .background(Color(uiColor: .systemGroupedBackground))
}
