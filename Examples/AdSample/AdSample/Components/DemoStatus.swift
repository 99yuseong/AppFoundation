//
//  DemoStatus.swift
//  AdSample
//
//  데모 공통 상태 — 각 섹션이 로드/표시 흐름을 색상 배지 하나로 보여준다.
//

import SwiftUI
import AdKit

/// 데모 섹션의 진행 상태. 연관값 문자열이 배지에 그대로 노출된다.
enum DemoStatus: Equatable {
    case idle
    case loading
    case ready
    case success(String)
    case failure(String)
    /// 성공/실패가 아닌 중립 상태 (예: ATT 미결정).
    case note(String)

    var text: String {
        switch self {
        case .idle: "미로드"
        case .loading: "로드 중"
        case .ready: "준비됨"
        case .success(let message), .failure(let message), .note(let message): message
        }
    }

    var color: Color {
        switch self {
        case .idle, .note: .secondary
        case .loading: .orange
        case .ready, .success: .green
        case .failure: .red
        }
    }

    /// nil 이면 배지에 ProgressView 를 그린다.
    var iconName: String? {
        switch self {
        case .idle: "circle.dashed"
        case .loading: nil
        case .ready, .success: "checkmark.circle.fill"
        case .failure: "xmark.circle.fill"
        case .note: "questionmark.circle"
        }
    }
}

/// 에러를 배지에 넣을 짧은 설명으로 변환.
func demoErrorText(_ error: Error) -> String {
    guard let adError = error as? AdError else { return error.localizedDescription }
    switch adError {
    case .noFill: return "no-fill"
    case .notReady: return "광고 미준비"
    case .alreadyPresenting: return "다른 광고 표시 중"
    case .loadFailed(let underlying): return underlying.localizedDescription
    case .presentationFailed(let underlying): return "표시 실패 — \(underlying.localizedDescription)"
    }
}
