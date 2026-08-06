import ExperimentKit
import Testing

private enum TestVariant: String, Sendable {
    case control
    case treatment
}

@Suite("ExperimentKit")
struct ExperimentKitTests {
    @Test("RawRepresentable variant를 타입으로 변환한다")
    func decodesVariant() {
        let client = InMemoryExperimentClient(values: ["sample": "treatment"])
        let key = ExperimentKey(
            name: "sample",
            defaultValue: TestVariant.control
        )

        #expect(client.value(for: key) == .treatment)
    }

    @Test("값이 없거나 알 수 없으면 기본값을 사용한다")
    func fallsBackToDefault() {
        let client = InMemoryExperimentClient(values: ["sample": "unknown"])
        let key = ExperimentKey(
            name: "sample",
            defaultValue: TestVariant.control
        )

        #expect(client.value(for: key) == .control)
    }

    @Test("기본 원시 타입을 변환한다")
    func decodesPrimitives() {
        let client = InMemoryExperimentClient(values: [
            "enabled": "true",
            "count": "3",
            "ratio": "0.5",
        ])

        #expect(client.value(for: ExperimentKey(name: "enabled", defaultValue: false)))
        #expect(client.value(for: ExperimentKey(name: "count", defaultValue: 0)) == 3)
        #expect(client.value(for: ExperimentKey(name: "ratio", defaultValue: 0.0)) == 0.5)
    }
}
