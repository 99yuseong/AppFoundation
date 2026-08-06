import Foundation

/// 원격 문자열을 앱의 타입으로 안전하게 변환하는 실험 키.
public struct ExperimentKey<Value: Sendable>: Sendable {
    public let name: String
    public let defaultValue: Value
    private let decodeValue: @Sendable (String) -> Value?

    public init(
        name: String,
        defaultValue: Value,
        decode: @escaping @Sendable (String) -> Value?
    ) {
        self.name = name
        self.defaultValue = defaultValue
        self.decodeValue = decode
    }

    public init(
        name: String,
        defaultValue: Value
    ) where Value: RawRepresentable, Value.RawValue == String {
        self.init(
            name: name,
            defaultValue: defaultValue,
            decode: Value.init(rawValue:)
        )
    }

    public func decode(_ rawValue: String?) -> Value {
        guard let rawValue, let value = decodeValue(rawValue) else {
            return defaultValue
        }
        return value
    }
}

public extension ExperimentKey where Value == String {
    init(name: String, defaultValue: String) {
        self.init(name: name, defaultValue: defaultValue) { $0 }
    }
}

public extension ExperimentKey where Value == Bool {
    init(name: String, defaultValue: Bool) {
        self.init(name: name, defaultValue: defaultValue) {
            switch $0.lowercased() {
            case "true", "1", "yes": true
            case "false", "0", "no": false
            default: nil
            }
        }
    }
}

public extension ExperimentKey where Value == Int {
    init(name: String, defaultValue: Int) {
        self.init(name: name, defaultValue: defaultValue, decode: Int.init)
    }
}

public extension ExperimentKey where Value == Double {
    init(name: String, defaultValue: Double) {
        self.init(name: name, defaultValue: defaultValue, decode: Double.init)
    }
}
