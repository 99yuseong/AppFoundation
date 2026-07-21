// swift-tools-version: 6.2
import PackageDescription

// AppFoundation — 여러 앱이 공유하는 공통 모듈 모음.
//
// 디렉토리 규칙: Sources/{Domain}/{Target}
//   Core/     CoreKit
//   Auth/     AuthKit, AuthKitGoogle, AuthKitKakao, AuthKitSupabase
//   (추후)    Ads/AdsKit, Purchase/PurchaseKit, Analytics/AnalyticsKit, Push/…
//
// product 분리 원칙: 외부 SDK 의존이 있는 provider/백엔드는 별도 product 로 둔다.
// SPM 은 product 단위로 링크하므로, 앱은 자기가 쓰는 provider 만 골라 추가하면
// 안 쓰는 SDK(KakaoSDK, GoogleSignIn)가 바이너리에 딸려 오지 않는다.

let package = Package(
    name: "AppFoundation",
    defaultLocalization: "ko",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CoreKit",         targets: ["CoreKit"]),
        .library(name: "AuthKit",         targets: ["AuthKit"]),
        .library(name: "AuthKitGoogle",   targets: ["AuthKitGoogle"]),
        .library(name: "AuthKitKakao",    targets: ["AuthKitKakao"]),
        .library(name: "AuthKitSupabase", targets: ["AuthKitSupabase"]),
    ],
    dependencies: [
        // 하한 = TumTumRead 현재 pin(2.29.3). Doran(2.51.0)과 range 호환.
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.29.3"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "9.2.0"),
        .package(url: "https://github.com/kakao/kakao-ios-sdk", from: "2.28.0"),
    ],
    targets: [
        .target(
            name: "CoreKit",
            path: "Sources/Core/CoreKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "AuthKit",
            dependencies: ["CoreKit"],
            path: "Sources/Auth/AuthKit",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "AuthKitGoogle",
            dependencies: [
                "AuthKit",
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
            ],
            path: "Sources/Auth/AuthKitGoogle",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "AuthKitKakao",
            dependencies: [
                "AuthKit",
                .product(name: "KakaoSDKCommon", package: "kakao-ios-sdk"),
                .product(name: "KakaoSDKAuth", package: "kakao-ios-sdk"),
                .product(name: "KakaoSDKUser", package: "kakao-ios-sdk"),
            ],
            path: "Sources/Auth/AuthKitKakao",
            // KakaoSDK 완료 핸들러가 Sendable 미표기 — v6 strict 에서 소음이 커
            // v5 모드로 둔다 (Doran AdKit 과 같은 선례).
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "AuthKitSupabase",
            dependencies: [
                "AuthKit",
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            path: "Sources/Auth/AuthKitSupabase",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AuthKitTests",
            dependencies: ["AuthKit"],
            path: "Tests/Auth/AuthKitTests"
        ),
        .testTarget(
            name: "AuthKitSupabaseTests",
            dependencies: ["AuthKitSupabase"],
            path: "Tests/Auth/AuthKitSupabaseTests"
        ),
    ]
)
