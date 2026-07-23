//
//  RemoteUIImage.swift
//  AppFoundation / ImageKit
//
//  원격 이미지 뷰 (UIKit). SwiftUI 의 `RemoteImage` 와 동일한 파이프라인·규칙을
//  `UIImageView` 서브클래스로 제공한다. 빌더는 `@discardableResult` + Self 반환
//  (`SocialLoginUIButton` 컨벤션), 로드는 `setImageURL(_:)` 이 트리거한다.
//
//      let imageView = RemoteUIImage()
//          .setMaxPixelSize(600)
//          .setFade(duration: 0.25)
//          .setImageURL(item.thumbnailURL)
//
//  셀 재사용: `setImageURL(_:)` 재호출이 이전 로드를 자동 취소하고,
//  `prepareForReuse` 에서 명시적으로 끊으려면 `cancelLoad()` 를 부른다.
//  페이드는 디스크/네트워크 로드에만 적용된다 — 메모리 히트는 즉시 표시.
//

import UIKit

public final class RemoteUIImage: UIImageView {

    // MARK: - 설정값

    private var loader: ImageLoader = .shared
    private var maxPixelSize: CGFloat?
    private var forceRefresh = false
    private var retry: RetryStrategy?
    private var fadeDuration: TimeInterval?
    private var placeholderImage: UIImage?
    private var failureImage: UIImage?
    private var showsActivityIndicator = false
    private var onProgress: ImageLoader.ProgressHandler?
    private var onSuccess: ((ImageLoadResult) -> Void)?
    private var onFailure: ((any Error) -> Void)?

    // MARK: - 상태

    private var loadTask: Task<Void, Never>?
    private var currentURL: URL?
    private var indicator: UIActivityIndicatorView?

    // MARK: - set 모디파이어 (빌더, Self 반환)

    /// 로드 파이프라인 교체 (기본 `ImageLoader.shared`) — 테스트·전용 세션 용.
    @discardableResult
    public func setLoader(_ loader: ImageLoader) -> Self {
        self.loader = loader
        return self
    }

    /// 다운샘플링 목표 — 긴 변 기준 픽셀 상한. 셀 썸네일이면 표시 크기 × scale 로 준다.
    @discardableResult
    public func setMaxPixelSize(_ maxPixelSize: CGFloat) -> Self {
        self.maxPixelSize = maxPixelSize
        return self
    }

    /// 캐시를 건너뛰고 네트워크에서 새로 받는다.
    @discardableResult
    public func setForceRefresh(_ forceRefresh: Bool = true) -> Self {
        self.forceRefresh = forceRefresh
        return self
    }

    /// 네트워크 실패 재시도 정책.
    @discardableResult
    public func setRetry(maxCount: Int, interval: Duration = .seconds(1)) -> Self {
        retry = RetryStrategy(maxCount: maxCount, interval: interval)
        return self
    }

    /// 로드 완료 시 페이드 인 (cross-dissolve). 디스크/네트워크 로드에만 적용된다.
    @discardableResult
    public func setFade(duration: TimeInterval = 0.25) -> Self {
        fadeDuration = duration
        return self
    }

    /// 로드 전·중에 표시할 이미지.
    @discardableResult
    public func setPlaceholderImage(_ image: UIImage?) -> Self {
        placeholderImage = image
        return self
    }

    /// 로드 실패 시 표시할 이미지. 미설정이면 placeholder 를 유지한다.
    @discardableResult
    public func setFailureImage(_ image: UIImage?) -> Self {
        failureImage = image
        return self
    }

    /// 로드 중 중앙에 스피너 표시.
    @discardableResult
    public func setShowsActivityIndicator(_ shows: Bool = true) -> Self {
        showsActivityIndicator = shows
        return self
    }

    /// 다운로드 진행률 (received, total — total 미상이면 -1). 백그라운드에서 불릴 수 있다.
    @discardableResult
    public func setOnProgress(_ handler: @escaping ImageLoader.ProgressHandler) -> Self {
        onProgress = handler
        return self
    }

    /// 로드 성공 콜백 (메인 액터).
    @discardableResult
    public func setOnSuccess(_ handler: @escaping (ImageLoadResult) -> Void) -> Self {
        onSuccess = handler
        return self
    }

    /// 로드 실패 콜백 (메인 액터).
    @discardableResult
    public func setOnFailure(_ handler: @escaping (any Error) -> Void) -> Self {
        onFailure = handler
        return self
    }

    // MARK: - 로드

    /// 로드 트리거. 재호출 시 이전 로드는 자동 취소된다. nil 이면 취소 + placeholder 로.
    @discardableResult
    public func setImageURL(_ url: URL?) -> Self {
        loadTask?.cancel()
        currentURL = url
        image = placeholderImage

        guard let url else {
            loadTask = nil
            stopIndicator()
            return self
        }

        if showsActivityIndicator {
            startIndicator()
        }

        let options = ImageLoadOptions(
            maxPixelSize: maxPixelSize,
            forceRefresh: forceRefresh,
            retry: retry
        )

        loadTask = Task { [weak self, loader, onProgress] in
            do {
                let result = try await loader.image(for: url, options: options, onProgress: onProgress)
                guard let self, !Task.isCancelled, self.currentURL == url else { return }

                self.stopIndicator()
                self.apply(result)
                self.onSuccess?(result)

            } catch is CancellationError {
                // 취소는 실패가 아니다 — 상태를 건드리지 않는다.
            } catch {
                guard let self, !Task.isCancelled, self.currentURL == url else { return }

                self.stopIndicator()
                if let failureImage = self.failureImage {
                    self.image = failureImage
                }
                self.onFailure?(error)
            }
        }
        return self
    }

    /// 진행 중인 로드 대기를 끊는다 (`prepareForReuse` 용). 공유 다운로드 자체는
    /// 계속돼 캐시를 데운다 — 같은 URL 재요청 시 즉시 히트.
    public func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
        stopIndicator()
    }

    // MARK: - 표시

    private func apply(_ result: ImageLoadResult) {
        if let fadeDuration, result.source != .memory {
            UIView.transition(
                with: self,
                duration: fadeDuration,
                options: [.transitionCrossDissolve, .allowUserInteraction]
            ) {
                self.image = result.image
            }
        } else {
            image = result.image
        }
    }

    private func startIndicator() {
        if indicator == nil {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.hidesWhenStopped = true
            spinner.translatesAutoresizingMaskIntoConstraints = false
            addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
            indicator = spinner
        }
        indicator?.startAnimating()
    }

    private func stopIndicator() {
        indicator?.stopAnimating()
    }
}
