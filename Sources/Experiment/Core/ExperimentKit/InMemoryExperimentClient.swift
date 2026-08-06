import Foundation

/// Preview와 단위 테스트에서 사용하는 SDK 무의존 구현체.
public final class InMemoryExperimentClient: ExperimentClient, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String]

    public init(values: [String: String] = [:]) {
        self.values = values
    }

    public func fetchAndActivate(
        policy: ExperimentFetchPolicy
    ) async throws -> ExperimentFetchResult {
        .usingCachedValue
    }

    public func value<Value: Sendable>(
        for key: ExperimentKey<Value>
    ) -> Value {
        let rawValue = lock.withLock { values[key.name] }
        return key.decode(rawValue)
    }

    public func set(_ rawValue: String?, forKey name: String) {
        lock.withLock {
            values[name] = rawValue
        }
    }
}
