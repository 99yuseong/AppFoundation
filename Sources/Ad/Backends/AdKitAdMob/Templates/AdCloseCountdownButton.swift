//
//  AdCloseCountdownButton.swift
//  AppFoundation / AdKitAdMob
//
//  전면 광고 닫기 버튼.
//
//  - 카운트다운 동안: 원형 프로그레스 링이 차오르며 남은 초를 표시하고, 탭해도 닫히지 않는다.
//  - 카운트다운 종료 시: X 닫기 버튼으로 전환(페이드 인 + 스프링)되며 탭하면 `onTapped`가 호출된다.
//

import UIKit

final class AdCloseCountdownButton: UIView {

    // MARK: - Callbacks

    var onTapped: (() -> Void)?

    // MARK: - UI Components

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        config.title = String(localized: "Ad.Interstitial.Close", bundle: .module)
        config.imagePadding = 6
        config.baseForegroundColor = UIColor.white.withAlphaComponent(0.7)
        button.configuration = config

        // 카운트다운이 끝날 때까지 숨겨둔다
        button.isEnabled = false
        button.alpha = 0
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 카운트다운(원형 프로그레스 + 숫자)을 담는 컨테이너
    private let countdownView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let countdownLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let progressRingLayer = CAShapeLayer()
    private let progressTrackLayer = CAShapeLayer()

    private var countdownTimer: Timer?
    private let ringSize: CGFloat = 44

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureUI()
    }

    deinit {
        countdownTimer?.invalidate()
    }

    // MARK: - Configuration

    private func configureUI() {
        configureHierarchy()
        configureLayout()
        configureProgressRing()
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
    }

    private func configureHierarchy() {
        addSubview(countdownView)
        addSubview(closeButton)
        countdownView.addSubview(countdownLabel)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            countdownView.centerXAnchor.constraint(equalTo: centerXAnchor),
            countdownView.centerYAnchor.constraint(equalTo: centerYAnchor),
            countdownView.widthAnchor.constraint(equalToConstant: ringSize),
            countdownView.heightAnchor.constraint(equalToConstant: ringSize),

            countdownLabel.centerXAnchor.constraint(equalTo: countdownView.centerXAnchor),
            countdownLabel.centerYAnchor.constraint(equalTo: countdownView.centerYAnchor),

            closeButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.topAnchor.constraint(equalTo: topAnchor),
            closeButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            closeButton.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            closeButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])
    }

    private func configureProgressRing() {
        progressTrackLayer.fillColor = UIColor.clear.cgColor
        progressTrackLayer.strokeColor = UIColor.white.withAlphaComponent(0.2).cgColor
        progressTrackLayer.lineWidth = 3
        countdownView.layer.addSublayer(progressTrackLayer)

        // 진행 링 (12시 방향에서 시작해 시계 방향으로 채워짐)
        progressRingLayer.fillColor = UIColor.clear.cgColor
        progressRingLayer.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
        progressRingLayer.lineWidth = 3
        progressRingLayer.lineCap = .round
        progressRingLayer.strokeEnd = 0
        countdownView.layer.addSublayer(progressRingLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutProgressRing()
    }

    private func layoutProgressRing() {
        let size = ringSize
        let inset = progressRingLayer.lineWidth / 2
        let rect = CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: inset, dy: inset)
        let path = UIBezierPath(
            arcCenter: CGPoint(x: size / 2, y: size / 2),
            radius: rect.width / 2,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        progressTrackLayer.path = path.cgPath
        progressRingLayer.path = path.cgPath
        progressTrackLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        progressRingLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)
    }

    // MARK: - Public Methods

    /// 카운트다운을 시작한다.
    /// - Parameter duration: 대기 시간(초). 0 이하이면 즉시 닫기 버튼을 노출한다.
    func startCountdown(duration: TimeInterval) {
        countdownTimer?.invalidate()

        guard duration > 0 else {
            revealCloseButton()
            return
        }

        // 초기 상태
        closeButton.isEnabled = false
        closeButton.alpha = 0
        countdownView.alpha = 1
        layoutIfNeeded()

        let totalSeconds = Int(ceil(duration))
        countdownLabel.text = "\(totalSeconds)"

        // 링을 빈 상태(0)로 즉시 초기화 (implicit 애니메이션 차단으로 꽉 찬 채 깜빡이는 현상 방지)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressRingLayer.strokeEnd = 0
        CATransaction.commit()

        // 원형 링 채우기 애니메이션 (0 → 1)
        let ringAnimation = CABasicAnimation(keyPath: "strokeEnd")
        ringAnimation.fromValue = 0
        ringAnimation.toValue = 1
        ringAnimation.duration = duration
        ringAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        ringAnimation.fillMode = .forwards
        ringAnimation.isRemovedOnCompletion = false
        progressRingLayer.add(ringAnimation, forKey: "ringProgress")

        // 매초 숫자 갱신
        var remaining = totalSeconds
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { return }
            remaining -= 1
            if remaining <= 0 {
                timer.invalidate()
                self.revealCloseButton()
            } else {
                self.countdownLabel.text = "\(remaining)"
            }
        }
    }

    // MARK: - Private

    /// 카운트다운을 종료하고 닫기 버튼을 노출한다.
    private func revealCloseButton() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        guard !closeButton.isEnabled else { return }

        closeButton.isEnabled = true
        closeButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        UIView.animate(withDuration: 0.25) {
            self.countdownView.alpha = 0
        }

        UIView.animate(
            withDuration: 0.4,
            delay: 0.1,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut]
        ) {
            self.closeButton.alpha = 1
            self.closeButton.transform = .identity
        }
    }

    @objc private func closeButtonTapped() {
        onTapped?()
    }
}
