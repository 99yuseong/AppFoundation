//
//  DemoPrivateBucket.swift
//  StorageSample
//
//  리허설용 private 버킷. R2 에 같은 이름의 버킷을 만들어 둔다.
//  버킷 = StorageBucket 준수 타입 하나 (버킷명·공개 여부·만료 정책의 단일 출처).
//

import APIKit

enum DemoPrivateBucket: StorageBucket {
    static let bucketName = "storage-sample"
    static let isPublic = false
    // signedURLExpiry 기본 1시간 — 캐시 검증이 목적이라 그대로 둔다.
}
