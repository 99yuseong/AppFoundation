import Foundation

public protocol ExperimentClient: Sendable {
    func fetchAndActivate(
        policy: ExperimentFetchPolicy
    ) async throws -> ExperimentFetchResult

    func value<Value: Sendable>(
        for key: ExperimentKey<Value>
    ) -> Value
}

public enum ExperimentFetchPolicy: Sendable, Equatable {
    case cached
    case expiration(TimeInterval)
    case fresh
}

public enum ExperimentFetchResult: Sendable, Equatable {
    case activated
    case usingCachedValue
}
