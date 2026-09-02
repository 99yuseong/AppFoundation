//
//  DemoStorageCenter.swift
//  StorageSample
//
//  Composition Root — Info.plist 설정에서 SupabaseClient(익명 로그인 = JWT 공급원)와
//  R2StorageClient(티켓제 업로드/표시)를 조립한다. 실제 앱도 같은 모양이다 —
//  APIClient 와 별개로 StorageClient 하나를 조립해 Repository 에 직주입하고,
//  저장소 교체는 이 파일의 구현 대입 한 줄이다 (docs/api/01-storage.md 조립 절).
//

import Foundation
import CoreKit
import APIKit
import Supabase

enum DemoStorageCenter {

    static let supabase: SupabaseClient = SupabaseClient(
        supabaseURL: URL(string: ConfigValues.require("SUPABASE_URL"))!,
        supabaseKey: ConfigValues.require("SUPABASE_ANON_KEY")
    )

    /// R2 실행 경로. Worker 가 Supabase JWT 를 검증하므로 tokenProvider 를 세션에 연결한다.
    static let storage: any StorageClient = R2StorageClient(
        signer: WorkerR2Signer(
            workerURL: URL(string: ConfigValues.require("STORAGE_WORKER_URL"))!,
            tokenProvider: { try await supabase.auth.session.accessToken }
        )
    )
}
