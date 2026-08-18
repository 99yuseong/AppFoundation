//
//  DemoStatusRow.swift
//  AdSample
//

import SwiftUI

/// "제목 — 상태 배지" 한 줄.
struct DemoStatusRow: View {

    let title: String
    let status: DemoStatus

    var body: some View {
        LabeledContent(title) {
            DemoStatusBadge(status: status)
        }
    }
}
