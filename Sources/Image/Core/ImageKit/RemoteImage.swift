//
//  RemoteImage.swift
//  AppFoundation / ImageKit
//
//  원격 이미지 뷰 (SwiftUI). `ImageLoader` 파이프라인(메모리→디스크→네트워크)으로
//  로드하고, 설정값은 전부 내부 변수 + `set~` 빌더 모디파이어로 수정한다
//  (`SocialLoginButton` 컨벤션). 이미지는 resizable 로 그려지므로 frame/aspectRatio
//  는 호출부가 뷰 모디파이어로 정한다.
//
//      RemoteImage(url: item.thumbnailURL)
//          .setMaxPixelSize(600)
//          .setPlaceholder { ProgressView() }
//          .setFade(duration: 0.25)
//          .aspectRatio(contentMode: .fill)
//
//  페이드는 디스크/네트워크 로드에만 적용된다 — 메모리 히트는 즉시 표시
//  (스크롤 복귀 시 깜빡임 방지, Kingfisher 와 동일한 규칙).
//

import SwiftUI

public struct RemoteImage: View {

    // MARK: - 설정값 (set 모디파이어로 수정)

    private let url: URL?
    private var loader: ImageLoader = .shared
    private var maxPixelSize: CGFloat?
    private var forceRefresh = false
    private var retry: RetryStrategy?
    private var fadeDuration: TimeInterval?
    private var cancelOnDisappear = false
    private var placeholder: AnyView?
    private var failureImage: UIImage?
    private var onProgress: ImageLoader.ProgressHandler?
    private var onSuccess: (@MainActor (ImageLoadResult) -> Void)?
    private var onFailure: (@MainActor (any Error) -> Void)?

    // MARK: - 상태

    private enum Phase {
        case empty
        case success(UIImage)
        case failure
    }

    @State private var phase: Phase = .empty
    @State private var loadTask: Task<Void, Never>?

    public init(url: URL?) {
        self.url = url
    }

    // MARK: - set 모디파이어 (빌더)

    /// 로드 파이프라인 교체 (기본 `ImageLoader.shared`) — 테스트·전용 세션 용.
    public func setLoader(_ loader: ImageLoader) -> Self {
        copy { $0.loader = loader }
    }

    /// 다운샘플링 목표 — 긴 변 기준 픽셀 상한. 셀 썸네일이면 표시 크기 × scale 로 준다.
    public func setMaxPixelSize(_ maxPixelSize: CGFloat) -> Self {
        copy { $0.maxPixelSize = maxPixelSize }
    }

    /// 캐시를 건너뛰고 네트워크에서 새로 받는다.
    public func setForceRefresh(_ forceRefresh: Bool = true) -> Self {
        copy { $0.forceRefresh = forceRefresh }
    }

    /// 네트워크 실패 재시도 정책.
    public func setRetry(maxCount: Int, interval: Duration = .seconds(1)) -> Self {
        copy { $0.retry = RetryStrategy(maxCount: maxCount, interval: interval) }
    }

    /// 로드 완료 시 페이드 인. 디스크/네트워크 로드에만 적용된다 (메모리 히트 제외).
    public func setFade(duration: TimeInterval = 0.25) -> Self {
        copy { $0.fadeDuration = duration }
    }

    /// 뷰가 사라질 때 진행 중인 로드 대기를 취소한다. 기본 false —
    /// 공유 다운로드 자체는 계속돼 캐시를 데우므로, 재등장 시 즉시 히트한다.
    public func setCancelOnDisappear(_ cancel: Bool = true) -> Self {
        copy { $0.cancelOnDisappear = cancel }
    }

    /// 로드 전·중에 표시할 뷰.
    public func setPlaceholder<Placeholder: View>(
        @ViewBuilder _ placeholder: () -> Placeholder
    ) -> Self {
        let view = AnyView(placeholder())
        return copy { $0.placeholder = view }
    }

    /// 로드 실패 시 표시할 이미지. 미설정이면 placeholder 를 유지한다.
    public func setFailureImage(_ image: UIImage?) -> Self {
        copy { $0.failureImage = image }
    }

    /// 다운로드 진행률 (received, total — total 미상이면 -1). 백그라운드에서 불릴 수 있다.
    public func setOnProgress(_ handler: @escaping ImageLoader.ProgressHandler) -> Self {
        copy { $0.onProgress = handler }
    }

    /// 로드 성공 콜백 (메인 액터).
    public func setOnSuccess(_ handler: @escaping @MainActor (ImageLoadResult) -> Void) -> Self {
        copy { $0.onSuccess = handler }
    }

    /// 로드 실패 콜백 (메인 액터).
    public func setOnFailure(_ handler: @escaping @MainActor (any Error) -> Void) -> Self {
        copy { $0.onFailure = handler }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var copied = self
        mutate(&copied)
        return copied
    }

    // MARK: - Body

    public var body: some View {
        content
            .onAppear {
                // 취소됐거나 아직 안 된 로드만 재개 — 성공 상태는 그대로 둔다.
                if case .success = phase { return }
                startLoad()
            }
            .onChange(of: url) {
                phase = .empty
                startLoad()
            }
            .onDisappear {
                if cancelOnDisappear {
                    loadTask?.cancel()
                    loadTask = nil
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .success(let image):
            Image(uiImage: image)
                .resizable()

        case .empty:
            placeholderView

        case .failure:
            if let failureImage {
                Image(uiImage: failureImage)
                    .resizable()
            } else {
                placeholderView
            }
        }
    }

    @ViewBuilder
    private var placeholderView: some View {
        if let placeholder {
            placeholder
        } else {
            Color(.secondarySystemBackground)
        }
    }

    // MARK: - 로드

    @MainActor
    private func startLoad() {
        loadTask?.cancel()

        guard let url else {
            loadTask = nil
            return
        }

        let options = ImageLoadOptions(
            maxPixelSize: maxPixelSize,
            forceRefresh: forceRefresh,
            retry: retry
        )

        loadTask = Task {
            do {
                let result = try await loader.image(for: url, options: options, onProgress: onProgress)
                guard !Task.isCancelled else { return }

                if let fadeDuration, result.source != .memory {
                    withAnimation(.easeInOut(duration: fadeDuration)) {
                        phase = .success(result.image)
                    }
                } else {
                    phase = .success(result.image)
                }
                onSuccess?(result)

            } catch is CancellationError {
                // 취소는 실패가 아니다 — 상태를 건드리지 않는다.
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failure
                onFailure?(error)
            }
        }
    }
}
