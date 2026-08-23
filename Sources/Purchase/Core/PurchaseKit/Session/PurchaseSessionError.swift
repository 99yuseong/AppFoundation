//
//  PurchaseSessionError.swift
//  AppFoundation / PurchaseKit
//

public enum PurchaseSessionError: Error, Equatable {
    /// 서비스 유저 id 를 확보하지 못해(또는 검증 실패) 결제 identity 를 세울 수 없다.
    case identityUnavailable
}
