//
//  LoginView.swift
//  AuthSample
//
//  SocialLoginButtonStack (SwiftUI) 데모 — 조립 시 등록한 provider 만
//  auth.loginOptions 로 노출된다. setIsLoading 바인딩, setCornerRadius 실시간 조정.
//

import AuthKit
import CoreKit
import SwiftUI
import UIKit

struct LoginView: View {

    let auth: any AuthService

    @State private var isLoading = false
    @State private var cornerRadius: CGFloat = 12
    @State private var logs: [String] = []

    var body: some View {
        VStack(spacing: 24) {
            Text("AuthKit SwiftUI 버튼")
                .font(.headline)

            // 등록된 provider 만, 주입 순서대로 — 배열이 단일 진실 소스.
            SocialLoginButtonStack(options: auth.loginOptions) { provider in
                signIn(provider)
            }
            .setCornerRadius(cornerRadius)
            .setIsLoading($isLoading)

            HStack {
                Text("cornerRadius \(Int(cornerRadius))")
                    .font(.caption.monospacedDigit())
                    .frame(width: 110, alignment: .leading)
                Slider(value: $cornerRadius, in: 0...26)
            }

            List(logs.reversed(), id: \.self) { log in
                Text(log).font(.caption.monospaced())
            }
            .listStyle(.plain)
        }
        .padding(20)
    }

    private func signIn(_ provider: SocialProvider) {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }

            do {
                let result = try await auth.signIn(with: provider) {
                    TopMostPresenter.topViewController() ?? UIViewController()
                }
                logs.append("✅ \(provider.rawValue) — uid=\(result.identity.uid)")

            } catch let error as AuthKitError where error.isCancelled {
                logs.append("↩️ \(provider.rawValue) — 사용자가 취소")

            } catch {
                logs.append("❌ \(provider.rawValue) — \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    LoginView(auth: MockAuthService())
}
