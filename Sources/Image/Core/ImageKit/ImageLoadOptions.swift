//
//  ImageLoadOptions.swift
//  AppFoundation / ImageKit
//
//  로드 한 건의 정책 선언. UI 컴포넌트의 set~ 모디파이어가 결국 이 값으로 수렴하고,
//  로더를 직접 쓰는 앱도 같은 타입을 쓴다.
//

import Foundation

public struct ImageLoadOptions: Sendable {

    /// 다운샘플링 목표 — 긴 변 기준 **픽셀** 상한. nil 이면 원본 크기로 디코드.
    /// 메모리 캐시 키에 포함된다 (같은 URL 도 크기별로 별도 항목).
    public var maxPixelSize: CGFloat?

    /// true 면 메모리·디스크 캐시를 건너뛰고 네트워크에서 새로 받는다.
    public var forceRefresh: Bool

    /// 네트워크 실패 시 재시도 정책. nil 이면 재시도 없음.
    public var retry: RetryStrategy?

    public init(
        maxPixelSize: CGFloat? = nil,
        forceRefresh: Bool = false,
        retry: RetryStrategy? = nil
    ) {
        self.maxPixelSize = maxPixelSize
        self.forceRefresh = forceRefresh
        self.retry = retry
    }
}

/// 고정 간격 재시도 (Kingfisher `DelayRetryStrategy` 상당). 취소는 재시도하지 않는다.
public struct RetryStrategy: Sendable {

    /// 최초 시도를 제외한 재시도 횟수.
    public var maxCount: Int

    /// 재시도 사이 대기 시간.
    public var interval: Duration

    public init(maxCount: Int, interval: Duration = .seconds(1)) {
        self.maxCount = maxCount
        self.interval = interval
    }
}
