// swift-tools-version: 6.2
import PackageDescription

// AppFoundation — 여러 앱이 공유하는 공통 모듈 모음.
//
// 디렉토리 규칙: Sources/{Domain}/{Layer}/{Target}
//   Core/                CoreKit (계층 없음 — 도메인 무관 기반)
//   Auth/Core/           AuthKit 코어 (타입·프로토콜·오케스트레이터·버튼)
//   Auth/Providers/      AuthKitApple, AuthKitGoogle, AuthKitKakao (credential 획득)
//   Auth/Backends/       AuthKitSupabase, AuthKitREST (credential ↔ 세션 교환)
//   API/Core/            APIKit (서버 API 계약 계층 — Endpoint·APIClient, SDK 무의존)
//   API/Backends/        APIKitSupabase (EF/RPC/DB/Storage/Realtime 실행),
//                        APIKitREST (URLSession 실행 — APIKit 타깃에 포함)
//   (추후)               Ads/AdsKit, Purchase/PurchaseKit, Analytics/AnalyticsKit, Push/…
//
// 타깃 분리 기준 = 외부 SDK 의존 (계층이 아니다).
// 계층은 디렉토리로 표현하고, 타깃은 SDK 경계에서만 쪼갠다 — 타깃이 늘수록
// 빌드 그래프만 무거워지므로 의존성 없는 계층끼리는 한 타깃으로 묶는다.
//   AuthKit  = Auth/Core/AuthKit + Auth/Backends/AuthKitREST (둘 다 의존성 zero)
//   APIKit   = API/Core/APIKit  + API/Backends/APIKitREST  (둘 다 의존성 zero)
// SPM 은 product 단위로 링크하므로, 앱은 자기가 쓰는 provider 만 골라 추가하면
// 안 쓰는 SDK(KakaoSDK, GoogleSignIn)가 바이너리에 딸려 오지 않는다.

let package = Package(
    name: "AppFoundation",
    defaultLocalization: "ko",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CoreKit",         targets: ["CoreKit"]),
        .library(name: "AuthKit",         targets: ["AuthKit"]),
        .library(name: "AuthKitApple",    targets: ["AuthKitApple"]),
        .library(name: "AuthKitGoogle",   targets: ["AuthKitGoogle"]),
        .library(name: "AuthKitKakao",    targets: ["AuthKitKakao"]),
        .library(name: "AuthKitSupabase", targets: ["AuthKitSupabase"]),
        .library(name: "APIKit",          targets: ["APIKit"]),
        .library(name: "APIKitSupabase",  targets: ["APIKitSupabase"]),
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
            exclude: ["CLAUDE.md"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Core + REST 백엔드를 한 타깃으로 묶는다 (둘 다 외부 의존 zero).
        // path 를 Sources/Auth 로 올리고 SDK 의존이 있는 형제 폴더만 제외한다 —
        // 계층 폴더 구조(Core/·Backends/)는 그대로 유지된다.
        .target(
            name: "AuthKit",
            dependencies: ["CoreKit"],
            path: "Sources/Auth",
            exclude: [
                "Providers",                    // 별도 타깃 (SDK 의존)
                "Backends/AuthKitSupabase",     // 별도 타깃 (supabase-swift)
                "Core/AuthKit/CLAUDE.md",
                "Backends/AuthKitREST/CLAUDE.md",
            ],
            resources: [.process("Core/AuthKit/Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "AuthKitApple",
            dependencies: ["AuthKit"],
            path: "Sources/Auth/Providers/AuthKitApple",
            exclude: ["CLAUDE.md"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "AuthKitGoogle",
            dependencies: [
                "AuthKit",
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
            ],
            path: "Sources/Auth/Providers/AuthKitGoogle",
            exclude: ["CLAUDE.md"],
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
            path: "Sources/Auth/Providers/AuthKitKakao",
            exclude: ["CLAUDE.md"],
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
            path: "Sources/Auth/Backends/AuthKitSupabase",
            exclude: ["CLAUDE.md"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Core + REST 백엔드를 한 타깃으로 묶는다 (AuthKit 과 같은 구조 — 둘 다 의존 zero).
        .target(
            name: "APIKit",
            path: "Sources/API",
            exclude: [
                "Backends/APIKitSupabase",      // 별도 타깃 (supabase-swift)
                "Core/APIKit/CLAUDE.md",
                "Backends/APIKitREST/CLAUDE.md",
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "APIKitSupabase",
            dependencies: [
                "APIKit",
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            path: "Sources/API/Backends/APIKitSupabase",
            exclude: ["CLAUDE.md"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CoreKitTests",
            dependencies: ["CoreKit"],
            path: "Tests/Core/CoreKitTests"
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
        .testTarget(
            name: "APIKitTests",
            dependencies: ["APIKit"],
            path: "Tests/API/APIKitTests"
        ),
        .testTarget(
            name: "APIKitSupabaseTests",
            dependencies: ["APIKitSupabase"],
            path: "Tests/API/APIKitSupabaseTests"
        ),
    ]
)
