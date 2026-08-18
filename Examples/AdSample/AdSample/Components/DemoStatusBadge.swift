//
//  DemoStatusBadge.swift
//  AdSample
//

import SwiftUI

/// `LabeledContent` 우측에 얹는 캡슐형 상태 배지.
struct DemoStatusBadge: View {

    let status: DemoStatus

    var body: some View {
        HStack(spacing: 4) {
            if let iconName = status.iconName {
                Image(systemName: iconName)
            } else {
                ProgressView()
                    .controlSize(.mini)
            }
            Text(status.text)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(status.color.opacity(0.12), in: Capsule())
    }
}
