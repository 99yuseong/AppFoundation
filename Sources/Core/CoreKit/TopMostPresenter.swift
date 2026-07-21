//
//  TopMostPresenter.swift
//  AppFoundation / CoreKit
//
//  SwiftUI 앱처럼 뷰컨트롤러를 직접 쥐고 있지 않은 호출부가 provider SDK 의
//  로그인 UI(Google 피커 등)를 띄울 presenting 뷰컨트롤러를 얻는 유틸.
//  (TumTumRead 의 UIApplication.currentUIWindow 패턴을 일반화)
//

import UIKit

@MainActor
public enum TopMostPresenter {

    /// 현재 foreground 활성 씬의 key window.
    public static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted { $0.activationState.presenterPriority > $1.activationState.presenterPriority }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    /// 현재 화면 최상단에 보이는 뷰컨트롤러 (presented / navigation / tab 체인을 따라간다).
    public static func topViewController() -> UIViewController? {
        guard var top = keyWindow()?.rootViewController else { return nil }

        while true {
            if let presented = top.presentedViewController {
                top = presented
            } else if let nav = top as? UINavigationController, let visible = nav.visibleViewController {
                top = visible
            } else if let tab = top as? UITabBarController, let selected = tab.selectedViewController {
                top = selected
            } else {
                return top
            }
        }
    }
}

private extension UIScene.ActivationState {
    var presenterPriority: Int {
        switch self {
        case .foregroundActive: 2
        case .foregroundInactive: 1
        default: 0
        }
    }
}
