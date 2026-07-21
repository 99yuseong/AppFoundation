//
//  UIKitLoginViewController.swift
//  AuthSample
//
//  SocialLoginUIButton (UIKit) 데모 — set~ 체이닝과 setLoading 상태 전환.
//

import AuthKit
import SwiftUI
import UIKit

struct UIKitLoginScreen: UIViewControllerRepresentable {
    let auth: any AuthService

    func makeUIViewController(context: Context) -> UIKitLoginViewController {
        UIKitLoginViewController(auth: auth)
    }

    func updateUIViewController(_ uiViewController: UIKitLoginViewController, context: Context) {}
}

final class UIKitLoginViewController: UIViewController {

    private let auth: any AuthService

    private lazy var buttons: [SocialLoginUIButton] = [
        SocialLoginUIButton()
            .setProvider(.apple)
            .setOnTap { [weak self] in self?.signIn(.apple) },
        SocialLoginUIButton()
            .setProvider(.kakao)
            .setCornerRadius(20)
            .setOnTap { [weak self] in self?.signIn(.kakao) },
        SocialLoginUIButton()
            .setProvider(.google)
            .setCornerRadius(26)
            .setHeight(56)
            .setOnTap { [weak self] in self?.signIn(.google) },
    ]

    private let logLabel = UILabel()

    init(auth: any AuthService) {
        self.auth = auth
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = "AuthKit UIKit 버튼"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center

        logLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logLabel.textAlignment = .center
        logLabel.numberOfLines = 0
        logLabel.text = "버튼을 눌러보세요"

        let stack = UIStackView(arrangedSubviews: [titleLabel] + buttons + [logLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(24, after: titleLabel)

        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
        ])
    }

    private func signIn(_ provider: SocialProvider) {
        buttons.forEach { $0.setLoading(true) }

        Task { @MainActor in
            defer { buttons.forEach { $0.setLoading(false) } }

            do {
                let result = try await auth.signIn(with: provider) { [weak self] in
                    self ?? UIViewController()
                }
                logLabel.text = "✅ \(provider.rawValue) — uid=\(result.identity.uid)"

            } catch let error as AuthKitError where error.isCancelled {
                logLabel.text = "↩️ \(provider.rawValue) — 사용자가 취소"

            } catch {
                logLabel.text = "❌ \(provider.rawValue) — \(error.localizedDescription)"
            }
        }
    }
}
