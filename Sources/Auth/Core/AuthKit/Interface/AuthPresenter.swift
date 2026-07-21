//
//  AuthPresenter.swift
//  AppFoundation / AuthKit
//

import UIKit

/// provider SDK(예: GoogleSignIn)가 로그인 UI 를 present 할 뷰컨트롤러를 공급한다.
/// 앱이 로그인 화면을 소유하고 이걸 넘겨주므로, Auth 계층은 뷰 계층에 직접 손대지
/// 않는다. Google 은 필수, Apple 은 anchor 힌트로만 쓰고 없으면 무시한다.
///
/// 뷰컨트롤러를 직접 쥐고 있지 않은 호출부(SwiftUI)는 CoreKit 의
/// `TopMostPresenter.topViewController()` 를 조합해 쓸 수 있다.
public typealias AuthPresenter = @MainActor @Sendable () -> UIViewController
