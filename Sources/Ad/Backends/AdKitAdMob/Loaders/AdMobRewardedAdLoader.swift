//
//  AdMobRewardedAdLoader.swift
//  AppFoundation / AdKitAdMob
//
//  보상형 광고를 온디맨드로 로드해 표시될 때까지 보관한다. prefetch 는 없다:
//  사용자가 시청을 선택한 시점에만 로드하므로 로드된 광고는 곧바로 표시된다 —
//  AdMob 의 show rate(일치율)를 건강하게 유지한다. 보상 지급은 서버 사이드다:
//  표시 전에 사용자 id 를 담은 ServerSideVerificationOptions 를 붙이면 AdMob
//  서버가 앱의 SSV 엔드포인트를 호출해 지급한다 — 클라이언트는 아무것도 직접
//  지급하지 않는다. 로컬 userDidEarnReward 콜백은 "시청을 끝냈다"만 알려주므로,
//  앱은 서버 정산 동안 "적립 중" 상태를 보여줄 수 있다.
//

import UIKit
import GoogleMobileAds
import AdKit
import os

@MainActor
public final class AdMobRewardedAdLoader: RewardedAdLoading {

    private let adUnitId: String
    private let log = Logger(subsystem: "AppFoundation", category: "AdKitAdMob.Rewarded")

    /// load-once 캐시 + TTL + in-flight 합류 — 중복 호출(더블 탭 등)은 같은
    /// 결과(에러 포함)를 기다린다. 합류 로직은 SDK 없이 단위 테스트되도록
    /// `SingleFlightCache`(AdKit)에 있다.
    private let cache: SingleFlightCache<RewardedAd>
    private var isPresenting = false

    /// - Parameters:
    ///   - adUnitId: placement 의 unit ID. 빈 값 = placement 비활성 (전체 no-op).
    ///   - cacheDuration: 미표시 잔여 캐시의 유효기간(초). GMA 광고는 로드 후
    ///     약 1시간 만료되므로 기본 1시간.
    public init(adUnitId: String, cacheDuration: TimeInterval? = 3600) {
        self.adUnitId = adUnitId
        self.cache = SingleFlightCache(
            cacheDuration: cacheDuration.map { .seconds($0) }
        )
    }

    /// 로드된 광고가 표시 가능 상태인가 (로드했지만 표시가 일어나지 않은 잔여분 —
    /// 다음 탭에서 즉시 표시된다).
    public var isAdReady: Bool { cache.isReady }

    /// 광고 1개를 로드한다. 캐시가 있으면 no-op. 사용자의 명시적 탭 시점에
    /// 호출되므로 실패는 그대로 사용자에게 노출한다 (재시도 백오프 없음).
    /// 진행 중인 로드가 있으면 합류해 그 결과(에러 포함)를 기다린다.
    /// no-fill 은 `AdError.noFill`, 그 외 실패는 `AdError.loadFailed`.
    public func loadAd() async throws {
        guard !adUnitId.isEmpty else { return }
        do {
            try await cache.loadIfNeeded {
                let ad = try await RewardedAd.load(with: self.adUnitId, request: Request())
                self.log.info("rewarded ad cached — unit: \(self.adUnitId)")
                return ad
            }
        } catch {
            log.warning("rewarded load failed — unit: \(self.adUnitId) error: \(error.localizedDescription)")
            throw AdError(gmaLoadError: error)
        }
    }

    /// 캐시된 광고를 표시하고 닫힐 때 반환된다. 반환값은 시청 완료 여부 —
    /// 실제 지급은 SSV 를 통해 서버가 결정한다. `userID` 가 있으면 SSV 옵션에
    /// 실어 보낸다. 로드된 광고가 없으면 `AdError.notReady`, 다른 광고 표시
    /// 중이면 `AdError.alreadyPresenting`(캐시 미소비), 표시 시작 실패는
    /// `AdError.presentationFailed` (호출부가 "표시 실패"(알림 대상)와 사용자의
    /// 중도 이탈(조용한 `false`)을 구분한다).
    public func present(from presenter: UIViewController, userID: String?) async throws -> Bool {
        // 호출 Task 가 이미 취소됐으면(화면 닫힘 등) 여기서 끊는다 — 취소가
        // 전파되지 않으면 다른 화면 위에 전면 광고가 뜬다. 캐시 소비 전에
        // 확인해 남은 광고는 다음 탭이 즉시 재생하도록 보존한다.
        try Task.checkCancellation()
        guard !isPresenting else { throw AdError.alreadyPresenting }
        guard let ad = cache.take() else { throw AdError.notReady }

        // SSV — AdMob 서버가 이 사용자 id 를 앱의 검증 엔드포인트로 에코해
        // 정확히 이 계정에 보상을 지급한다. present() 전에 설정해야 한다 —
        // 아니면 콜백에 사용자 id 가 빠져 지급이 일어나지 않는다.
        if let userID {
            let options = ServerSideVerificationOptions()
            options.userIdentifier = userID
            ad.serverSideVerificationOptions = options
        }

        do {
            try ad.canPresent(from: presenter)
        } catch {
            log.warning("rewarded cannot present: \(error.localizedDescription)")
            throw AdError.presentationFailed(underlying: error)
        }

        isPresenting = true
        defer { isPresenting = false }

        let awaiter = FullScreenPresentationAwaiter()
        var didEarnReward = false
        try await awaiter.present(ad) {
            ad.present(from: presenter) {
                didEarnReward = true
            }
        }
        return didEarnReward
    }
}
