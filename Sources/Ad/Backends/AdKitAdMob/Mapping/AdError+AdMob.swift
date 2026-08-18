//
//  AdError+AdMob.swift
//  AppFoundation / AdKitAdMob
//
//  GMA 로드 에러 → 도메인 에러 매핑. no-fill(정상적 미채움)과 그 외 실패를
//  구분해 앱 파사드가 분기할 수 있게 한다.
//

import Foundation
import GoogleMobileAds
import AdKit

extension AdError {

    /// GMA 로드 에러를 도메인 에러로 변환한다 — `GADErrorDomain` 의 no-fill
    /// 코드만 `.noFill`, 나머지는 전부 `.loadFailed`.
    init(gmaLoadError error: Error) {
        let nsError = error as NSError
        if nsError.domain == GADErrorDomain,
           nsError.code == RequestError.noFill.rawValue {
            self = .noFill
        } else {
            self = .loadFailed(underlying: error)
        }
    }
}
