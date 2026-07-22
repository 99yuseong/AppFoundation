//
//  SupabaseTable.swift
//  AppFoundation / APIKitSupabase
//
//  PostgREST 로 직접 조작하는 public 스키마 테이블을 타입으로 표현한다. 테이블/컬럼명을
//  문자열로 호출부에 흩뿌리면 서버 스키마가 바뀔 때 산재한 오타를 잡기 어렵다 — 이름을
//  각 테이블 타입 한 곳에 모아, 컬럼 화이트리스트(서버 GRANT)와 1:1로 맞춘다.
//
//  구조: 각 테이블은 이 프로토콜을 준수하는 별도 타입(앱 소유, 별도 파일)이다. 테이블명과
//  컬럼 화이트리스트를 자기가 소유하므로, 새 테이블은 준수 타입 하나를 추가하는 것으로 끝난다.
//

/// PostgREST 로 직접 조작하는 public 스키마 테이블. 준수 타입이 테이블명과 자기 컬럼
/// 화이트리스트(`Column`)를 소유한다. 준수 타입 자체는 인스턴스가 필요 없는 순수
/// 네임스페이스라 보통 case 없는 enum 으로 둔다.
public protocol SupabaseTable {

    /// PostgREST `.from(_:)` 에 실리는 실제 테이블명. 이 테이블 문자열의 유일한 출처.
    static var tableName: String { get }

    /// 이 테이블의 **UPDATE 화이트리스트** 컬럼. rawValue 가 실제 컬럼명이며, 서버 GRANT
    /// 목록과 정확히 일치해야 한다(그 외 컬럼은 클라 수정 금지). update 는 이 타입의 값만
    /// 받으므로 다른 테이블 컬럼이 섞이는 걸 컴파일러가 차단한다.
    associatedtype Column: RawRepresentable & Hashable where Column.RawValue == String
}
