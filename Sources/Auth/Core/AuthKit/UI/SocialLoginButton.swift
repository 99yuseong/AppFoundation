//
//  SocialLoginButton.swift
//  AppFoundation / AuthKit
//
//  소셜 로그인 버튼 (SwiftUI). provider switch 없이 주입된 `SocialLoginOption` 의
//  branding(문구·색·로고)만 그린다 — 새 provider 는 branding 값 하나로 노출된다.
//  설정값은 전부 내부 변수로 저장하고 `set~` 빌더 모디파이어로 수정한다.
//
//  보통은 조립한 옵션 목록을 그대로 그리는 `SocialLoginButtonStack` 을 쓰고,
//  이 타입은 수동 배치가 필요할 때 단독으로 쓴다:
//      SocialLoginButton(option: .init(provider: .kakao, branding: .kakao)) {
//          viewModel.signInKakao()
//      }
//      .setCornerRadius(16)
//      .setIsLoading($isLoading)
//

import SwiftUI

public struct SocialLoginButton: View {

    // MARK: - 설정값 (set 모디파이어로 수정)

    private let option: SocialLoginOption
    private var cornerRadius: CGFloat = 12
    private var height: CGFloat = 52
    private var isLoading: Binding<Bool> = .constant(false)

    private let action: @MainActor () -> Void

    public init(option: SocialLoginOption, action: @escaping @MainActor () -> Void) {
        self.option = option
        self.action = action
    }

    // MARK: - set 모디파이어 (빌더)

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

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var copied = self
        mutate(&copied)
        return copied
    }

    // MARK: - Body

    private var branding: SocialLoginBranding { option.branding }

    public var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: 8) {
                    LogoView(logo: branding.logo, foreground: branding.foreground)
                        .frame(width: 18, height: 18)
                    Text(branding.title)
                        .font(.system(size: 16, weight: .semibold))
                }
                .opacity(isLoading.wrappedValue ? 0 : 1)

                if isLoading.wrappedValue {
                    ProgressView()
                        .tint(Color(uiColor: branding.foreground))
                }
            }
            .foregroundStyle(Color(uiColor: branding.foreground))
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                Color(uiColor: branding.background),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .overlay {
                if let border = branding.border {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color(uiColor: border), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading.wrappedValue)
    }
}

// MARK: - 로고 렌더링 (branding.logo → SwiftUI)

private struct LogoView: View {

    let logo: SocialLoginBranding.Logo
    let foreground: UIColor

    var body: some View {
        switch logo {
        case let .sfSymbol(name, verticalOffset):
            Image(systemName: name)
                .font(.system(size: 17, weight: .medium))
                .offset(y: verticalOffset)

        case let .paths(segments):
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                for segment in segments(rect) {
                    context.fill(
                        Path(segment.path),
                        with: .color(Color(uiColor: segment.color ?? foreground))
                    )
                }
            }

        case let .image(image):
            // 브랜드 에셋은 원본 색 그대로 (tint 를 타지 않게 renderingMode 고정).
            Image(uiImage: image.withRenderingMode(.alwaysOriginal))
                .resizable()
                .scaledToFit()
        }
    }
}

// MARK: - Preview

#Preview("Options") {
    VStack(spacing: 12) {
        SocialLoginButton(option: .init(provider: .apple, branding: .apple())) {}
        SocialLoginButton(option: .init(provider: .kakao, branding: .kakao)) {}
        SocialLoginButton(option: .init(provider: .google, branding: .google)) {}
        SocialLoginButton(option: .init(provider: .apple, branding: .apple(.whiteOutline))) {}
        SocialLoginButton(option: .init(provider: .kakao, branding: .kakao)) {}
            .setIsLoading(.constant(true))
        SocialLoginButton(option: .init(provider: .google, branding: .google)) {}
            .setCornerRadius(26)
            .setHeight(56)
    }
    .padding(24)
    .background(Color(uiColor: .systemGroupedBackground))
}
