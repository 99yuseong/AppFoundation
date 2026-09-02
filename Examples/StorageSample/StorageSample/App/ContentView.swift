//
//  ContentView.swift
//  StorageSample
//

import SwiftUI

struct ContentView: View {

    @State private var model = UploadDemoModel()

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                uploadSection
                displaySection
            }
            .navigationTitle("R2 Storage 리허설")
        }
        .task { await model.signIn() }
    }

    private var statusSection: some View {
        Section("상태") {
            LabeledContent("로그인(익명)") {
                Text(model.userID.map { String($0.prefix(8)) + "…" } ?? "미로그인")
                    .foregroundStyle(model.isSignedIn ? .green : .secondary)
            }
            switch model.phase {
            case .idle:
                EmptyView()
            case .working(let message):
                HStack { ProgressView(); Text(message) }
            case .failed(let message):
                Text(message).foregroundStyle(.red).font(.footnote)
            }
        }
    }

    private var uploadSection: some View {
        Section("① 업로드 — 티켓(Worker 서명) + 직접 PUT") {
            Button("이미지 생성 → R2 업로드") {
                Task { await model.upload() }
            }
            .disabled(!model.isSignedIn)

            if let path = model.uploadedPath {
                LabeledContent("정본 path") {
                    Text(path).font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                }
            }
        }
    }

    private var displaySection: some View {
        Section("② 표시 — 서명 URL + 순수 GET") {
            if let url = model.displayURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)

                Button("표시 URL 재요청 (캐시 검증)") {
                    Task { await model.refreshDisplayURL() }
                }
                if let cached = model.lastLookupWasCached {
                    LabeledContent("SignedURLCache") {
                        Text(cached ? "적중 — 서명 왕복 없음" : "재발급")
                            .foregroundStyle(cached ? .green : .orange)
                    }
                }
            } else {
                Text("업로드하면 여기서 서명 URL 로 표시됩니다").foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
