//
//  ConfigValues.swift
//  AppFoundation / CoreKit
//
//  xcconfig → Info.plist 로 주입된 설정값을 읽는 공용 로더.
//  (TumTumRead 의 Bundle 확장, Doran 의 AppInfoPlist 패턴을 일반화)
//
//  사용 예:
//      let key = ConfigValues.require("SUPABASE_API_KEY")
//      let optional = ConfigValues.string("GOOGLE_CLIENT_ID")
//

import Foundation

public enum ConfigValues {

    /// Info.plist 에서 문자열 값을 읽는다. 없으면 nil.
    public static func string(_ key: String, bundle: Bundle = .main) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else { return nil }
        return value
    }

    /// Info.plist 에서 필수 문자열 값을 읽는다. 없으면 설정 누락이므로 즉시 크래시 —
    /// 조용히 빈 값으로 진행해 런타임 인증 실패로 이어지는 것보다 빌드 직후 드러나는 편이 낫다.
    public static func require(_ key: String, bundle: Bundle = .main) -> String {
        guard let value = string(key, bundle: bundle) else {
            fatalError("""
            [AppFoundation] Info.plist 에 '\(key)' 가 없습니다. \
            xcconfig 에 키를 추가하고 Info.plist 에 $(\(key)) 로 연결했는지 확인하세요.
            """)
        }
        return value
    }
}
