//
//  NativeAdLoading.swift
//  AppFoundation / AdKit
//
//  네이티브 광고 로더 계약 계열의 기본형 (단발 로드). 계열 공통 설계:
//
//  - associatedtype `Ad` 가 SDK 광고 타입을 추상화한다 — 계약은 SDK 를 모르고,
//    백엔드 로더가 자기 SDK 타입으로 채택한다. 앱 파사드·테스트는 계약
//    (또는 Mock/)에 의존한다.
//  - 렌더링(광고 객체 → 뷰 바인딩·트래킹) 계약은 계열에 없다 — SDK 뷰 타입이
//    필수라 백엔드 호스트가 소유한다.
//  - 전 계약이 @MainActor 격리라 `Ad: Sendable` 을 요구하지 않는다 (SDK 광고
//    객체는 대부분 non-Sendable — 격리 안에서만 다룬다).
//  - `any … Loading<Ad>` 존재형은 `@ObservedObject` 로 관찰할 수 없다 —
//    게시 값을 관찰해야 하는 뷰는 제네릭(`<L: NativeAdPersistentLoading>`)으로 받는다.
//

import UIKit

/// 단발 로드: 광고 1개를 async 로 돌려준다. 로드 주기는 호출부가 소유한다.
@MainActor
public protocol NativeAdLoading<Ad>: AnyObject {
    associatedtype Ad

    /// 네이티브 광고 1개를 로드한다. 광고 클릭 처리를 위해 루트 뷰컨트롤러를
    /// 받을 수 있다. no-fill 은 `AdError.noFill`, 그 외는 `AdError.loadFailed`.
    func load(rootViewController: UIViewController?) async throws -> Ad
}
