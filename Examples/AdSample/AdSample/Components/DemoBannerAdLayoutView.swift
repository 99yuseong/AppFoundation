//
//  DemoBannerAdLayoutView.swift
//  AdSample
//
//  `NativeAdLayoutUIView` 를 직접 상속하는 커스텀 레이아웃 예시 — 앱이 자기
//  디자인시스템으로 네이티브 광고를 그리는 경로다. UIKit + AdKit 만 import
//  한다 (GoogleMobileAds 불필요). 미디어 없이 아이콘·텍스트만 쓰는 소형 배너.
//

import UIKit
import AdKit

final class DemoBannerAdLayoutView: NativeAdLayoutUIView {

    private let adBadgeLabel: UILabel = {
        let label = UILabel()
        label.text = "AD"
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = .darkGray
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let headlineLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 1
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }()

    private let adChoicesSlotView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func setupLayout() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12

        let textStack = UIStackView(arrangedSubviews: [headlineLabel, bodyLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let rowStack = UIStackView(arrangedSubviews: [iconImageView, textStack])
        rowStack.axis = .horizontal
        rowStack.spacing = 10
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(rowStack)
        addSubview(adBadgeLabel)
        addSubview(adChoicesSlotView)

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),

            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            rowStack.trailingAnchor.constraint(lessThanOrEqualTo: adBadgeLabel.leadingAnchor, constant: -8),
            rowStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            adBadgeLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            adBadgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            adBadgeLabel.widthAnchor.constraint(equalToConstant: 26),
            adBadgeLabel.heightAnchor.constraint(equalToConstant: 16),

            adChoicesSlotView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            adChoicesSlotView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            adChoicesSlotView.widthAnchor.constraint(equalToConstant: 18),
            adChoicesSlotView.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    // MARK: - NativeAdLayoutUIView

    override var adHeadlineLabel: UILabel? { headlineLabel }
    override var adBodyLabel: UILabel? { bodyLabel }
    override var adIconImageView: UIImageView? { iconImageView }
    override var adChoicesContainerView: UIView? { adChoicesSlotView }
    override var usesWholeViewAsClickTarget: Bool { true }

    override func configure(with content: NativeAdContent) {
        headlineLabel.text = content.headline ?? "광고"
        bodyLabel.text = content.body
        if let icon = content.iconImage {
            iconImageView.image = icon
            iconImageView.tintColor = nil
        } else {
            iconImageView.image = UIImage(systemName: "megaphone.fill")
            iconImageView.tintColor = .tertiaryLabel
        }
    }

    override func configureDefaultContent() {
        headlineLabel.text = "광고 자리"
        bodyLabel.text = "로드 전/no-fill 기본 콘텐츠"
        iconImageView.image = UIImage(systemName: "megaphone.fill")
        iconImageView.tintColor = .tertiaryLabel
    }
}
