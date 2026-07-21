//
//  SocialLoginButtonStack.swift
//  AppFoundation / AuthKit
//
//  조립 시 등록한 provider 만 그리는 로그인 버튼 스택 (SwiftUI).
//  `AuthService.loginOptions` 를 그대로 받아 순서대로 노출한다 — 옵션 배열이
//  단일 진실 소스라 새 provider 가 추가돼도 이 코드는 바뀌지 않는다.
//
//  사용 예:
//      SocialLoginButtonStack(options: auth.loginOptions) { provider in
//          viewModel.signIn(provider)
//      }
//      .setCornerRadius(16)
//      .setSpacing(12)
//      .setIsLoading($isLoading)
//

import SwiftUI

public struct SocialLoginButtonStack: View {

    // MARK: - 설정값 (set 모디파이어로 수정)

    private let options: [SocialLoginOption]
    private var cornerRadius: CGFloat = 12
    private var height: CGFloat = 52
    private var spacing: CGFloat = 12
    private var isLoading: Binding<Bool> = .constant(false)

    private let action: @MainActor (SocialProvider) -> Void

    public init(
        options: [SocialLoginOption],
        action: @escaping @MainActor (SocialProvider) -> Void
    ) {
        self.options = options
        self.action = action
    }

    // MARK: - set 모디파이어 (빌더)

    /// 전 버튼 공통 모서리 반경. 기본 12.
    public func setCornerRadius(_ radius: CGFloat) -> Self {
        copy { $0.cornerRadius = radius }
    }

    /// 전 버튼 공통 높이. 기본 52.
    public func setHeight(_ height: CGFloat) -> Self {
        copy { $0.height = height }
    }

    /// 버튼 사이 간격. 기본 12.
    public func setSpacing(_ spacing: CGFloat) -> Self {
        copy { $0.spacing = spacing }
    }

    /// 로딩 상태 바인딩 — true 면 전 버튼 스피너 표시 + 터치 비활성.
    public func setIsLoading(_ isLoading: Binding<Bool>) -> Self {
        copy { $0.isLoading = isLoading }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var copied = self
        mutate(&copied)
        return copied
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: spacing) {
            ForEach(options, id: \.provider) { option in
                SocialLoginButton(option: option) { action(option.provider) }
                    .setCornerRadius(cornerRadius)
                    .setHeight(height)
                    .setIsLoading(isLoading)
            }
        }
    }
}

// MARK: - Preview

#Preview("Stack") {
    SocialLoginButtonStack(
        options: [
            SocialLoginOption(provider: .apple, branding: .apple()),
            SocialLoginOption(provider: .kakao, branding: .kakao),
            SocialLoginOption(provider: .google, branding: .google),
        ],
        action: { _ in }
    )
    .setCornerRadius(16)
    .padding(24)
    .background(Color(uiColor: .systemGroupedBackground))
}
