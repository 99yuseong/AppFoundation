import ExperimentKit
import Foundation
import Testing
@testable import ExperimentKitFirebase

@Suite("FetchPolicyMapping")
struct FetchPolicyMappingTests {
    @Test("cached 는 만료 없음 — fetch 를 사실상 건너뛴다")
    func cachedNeverExpires() {
        #expect(
            FetchPolicyMapping.expirationDuration(for: .cached)
                == TimeInterval.greatestFiniteMagnitude
        )
    }

    @Test("fresh 는 만료 0 — 즉시 갱신")
    func freshAlwaysFetches() {
        #expect(FetchPolicyMapping.expirationDuration(for: .fresh) == 0)
    }

    @Test("expiration 은 지정값을 쓰되 음수는 0 으로 클램프한다")
    func expirationClampsNegative() {
        #expect(FetchPolicyMapping.expirationDuration(for: .expiration(3600)) == 3600)
        #expect(FetchPolicyMapping.expirationDuration(for: .expiration(-5)) == 0)
    }
}
