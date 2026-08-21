//
//  DemoAdUnitID.swift
//  AdSample
//
//  Google 공식 테스트 unit ID — 항상 테스트 광고가 채워진다.
//  실서비스에서는 자기 unit ID 로 교체하고 xcconfig → Info.plist 주입을 쓴다
//  (docs/ad/00-overview.md 참고).
//

enum DemoAdUnitID {
    static let nativeAdvanced      = "ca-app-pub-3940256099942544/2247696110"
    static let nativeAdvancedVideo = "ca-app-pub-3940256099942544/1044960115"
    static let interstitial        = "ca-app-pub-3940256099942544/4411468910"
    static let rewarded            = "ca-app-pub-3940256099942544/5224354917"
}
