import ExperimentKit
import FirebaseRemoteConfig
import Foundation

/// Firebase A/B Testing이 Remote Config에 배정한 값을 제공하는 어댑터.
public final class FirebaseExperimentClient: ExperimentClient, @unchecked Sendable {
    private let remoteConfig: RemoteConfig

    public init(
        remoteConfig: RemoteConfig = .remoteConfig(),
        defaults: [String: NSObject] = [:]
    ) {
        self.remoteConfig = remoteConfig
        // setDefaults 는 전체 교체 — 빈 딕셔너리로 기존 등록분을 지우지 않는다.
        if !defaults.isEmpty {
            remoteConfig.setDefaults(defaults)
        }
    }

    public func fetchAndActivate(
        policy: ExperimentFetchPolicy
    ) async throws -> ExperimentFetchResult {
        let expirationDuration: TimeInterval
        switch policy {
        case .cached:
            expirationDuration = TimeInterval.greatestFiniteMagnitude
        case .expiration(let duration):
            expirationDuration = max(0, duration)
        case .fresh:
            expirationDuration = 0
        }

        let status = try await remoteConfig.fetch(withExpirationDuration: expirationDuration)
        guard status == .success else {
            return .usingCachedValue
        }

        let activated = try await remoteConfig.activate()
        return activated ? .activated : .usingCachedValue
    }

    public func value<Value: Sendable>(
        for key: ExperimentKey<Value>
    ) -> Value {
        let configValue = remoteConfig.configValue(forKey: key.name)
        // .static = 원격에도 defaults 에도 없는 키 — 빈 문자열이 넘어오므로
        // String 키의 defaultValue 가 무시되지 않게 여기서 폴백한다.
        guard configValue.source != .static else {
            return key.defaultValue
        }
        return key.decode(configValue.stringValue)
    }
}
