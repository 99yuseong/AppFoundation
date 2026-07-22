//
//  Endpoint.swift
//  AppFoundation / APIKit
//
//  서버 엔드포인트가 공통으로 제공하는 호출 메타데이터. Moya `TargetType` 상당 —
//  단, baseURL 은 백엔드 소유(엔드포인트가 호스트를 모르는 것이 백엔드 교체
//  무변경의 전제), sampleData 는 두지 않는다(테스트 픽스처는 MockAPIClient 로).
//

public protocol Endpoint: Sendable {

    /// 서버 계약 이름 (EF/RPC 함수명, REST 확장 시 라우트 식별자).
    var name: String { get }

    /// 전송 방식 — EF/RPC/DB/Storage/Realtime. 백엔드가 이 값으로 실행 경로를 고른다.
    var transport: EndpointTransport { get }

    /// 이 오퍼레이션의 HTTP 의미 분류 — 선언적, 강제 없음(GET+업로드도 막지 않는다).
    /// Supabase 백엔드는 전송에 쓰지 않지만(EF/RPC 는 게이트웨이가 POST 고정,
    /// DB/Storage 는 SDK 가 결정) 로그로 가시화하고, 자체 서버 확장 시 REST 백엔드가
    /// 실제 전송 verb 로 사용한다. 기본값 없음 — 모든 엔드포인트가 명시 선언한다.
    var method: HTTPMethod { get }

    /// 요청 페이로드의 선언적 분류. EF/RPC 는 `.json` 페이로드를 전송에 사용하고,
    /// DB/Storage/Realtime 은 엔드포인트가 직접 실행하므로 선언용이다.
    var task: EndpointTask { get }
}
