//
//  PurchaseError.swift
//  AppFoundation / PurchaseKit
//
//  SDK 무의존 에러 표면. RevenueCat/StoreKit 고유 에러는 각 백엔드의 Mapping 이
//  여기로 정규화한다 — 호출부가 SDK 에러 타입을 catch 하지 않는다.
//

import Foundation

public enum PurchaseError: Error {

    /// `configure()` 가 아직 호출되지 않았다.
    case notConfigured

    /// 식별자에 해당하는 상품이 현재 오퍼링/카탈로그에 없다.
    case productNotFound(ProductIdentifier)

    /// 상품 분류가 연산과 맞지 않는다.
    case unexpectedProductType(expected: ProductType, actual: ProductType)

    /// 사용자가 시스템 결제 시트를 닫았다.
    case cancelled

    /// 외부 승인 대기 중 (Ask to Buy / SCA).
    case purchasePending

    /// 시스템 UI(구독 관리·오퍼코드 시트)를 띄울 활성 윈도우 씬이 없다.
    case noActiveScene

    /// 스토어 SDK 실패 — 사람이 읽을 메시지.
    case storeError(message: String)

    /// 그 외 — 원본 에러 동봉.
    case unknown(Error)
}

public extension PurchaseError {

    /// 사용자가 단순히 시트를 닫은 경우 — 보통 에러 UI 없이 무시한다.
    var isCancelled: Bool {
        if case .cancelled = self { return true }
        return false
    }
}
