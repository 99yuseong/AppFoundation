//
//  NativeAdLayoutUIView.swift
//  AppFoundation / AdKit
//
//  네이티브 광고의 "디자인(콘텐츠 뷰)" 베이스 클래스.
//
//  백엔드(AdKitAdMob 등)는 연동 메커니즘(로더, 노출/클릭 트래킹, 프레젠테이션)을
//  소유하고, 실제 레이아웃·스타일·기본(no-fill) 콘텐츠는 이 클래스를 상속한 뷰가
//  소유한다. 앱은 자기 디자인시스템에 맞는 서브클래스를 만들어 백엔드의 호스트
//  뷰에 주입한다. 광고 SDK 타입이 전혀 노출되지 않으므로 서브클래스는
//  UIKit + AdKit 만 import 하면 되고, 같은 레이아웃을 다른 광고 백엔드에도
//  재사용할 수 있다.
//
//  미디어·AdChoices 는 서브클래스가 자리(컨테이너 UIView)만 잡는다 — 바인딩
//  시점에 백엔드 호스트가 SDK 의 미디어 뷰/AdChoices 뷰를 그 컨테이너에 꽉 채워
//  삽입하고 트래킹에 등록한다. 미디어 표시 방식은 컨테이너의 `contentMode` 를
//  삽입되는 SDK 뷰에 그대로 비춘다 (aspect fill 을 원하면 컨테이너에
//  `.scaleAspectFill` 을 설정).
//
//  ## 서브클래스가 오버라이드하는 것
//  - `setupLayout()` — 서브뷰 추가·레이아웃 구성 (init 에서 자동 호출됨)
//  - asset 뷰 프로퍼티 — 트래킹에 등록할 뷰만 반환
//  - `configure(with:)` / `configureDefaultContent()` — 광고 데이터/기본 콘텐츠 반영
//

import UIKit

open class NativeAdLayoutUIView: UIView {

    // MARK: - Initialization

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }

    // MARK: - Layout (오버라이드 포인트)

    /// 서브뷰 추가와 레이아웃 구성. init 에서 한 번 호출된다.
    open func setupLayout() {}

    // MARK: - Asset Views (트래킹 등록용 — 사용하는 것만 오버라이드)

    open var adHeadlineLabel: UILabel? { nil }
    open var adBodyLabel: UILabel? { nil }
    /// 미디어(영상/이미지)가 표시될 자리. 백엔드가 자기 미디어 뷰를 꽉 채워 삽입한다.
    open var adMediaContainerView: UIView? { nil }
    open var adFallbackImageView: UIImageView? { nil }
    open var adIconImageView: UIImageView? { nil }
    /// CTA 로 등록할 뷰. `usesWholeViewAsClickTarget` 이 true 면 무시된다.
    open var adCallToActionView: UIView? { nil }
    /// 광고 정보(AdChoices) 아이콘이 표시될 자리. 백엔드가 자기 뷰를 꽉 채워 삽입한다.
    open var adChoicesContainerView: UIView? { nil }

    // MARK: - Click Behavior (오버라이드 포인트)

    /// true 면 콘텐츠 전체(카드)를 광고 클릭 영역으로 등록한다. (전면 광고 카드 등)
    open var usesWholeViewAsClickTarget: Bool { false }

    /// true 면 콘텐츠가 hitTest 에서 nil 을 반환한 영역의 터치를 호스트도 통과시킨다.
    /// (하단 라인 광고처럼 콘텐츠 바깥 영역이 아래 뷰로 터치를 넘겨야 하는 경우)
    open var passesThroughTouchesOutsideContent: Bool { false }

    // MARK: - Content (오버라이드 포인트)

    /// 로드된 광고 데이터로 콘텐츠를 구성한다.
    /// (미디어 바인딩·트래킹 연결은 호스트가 수행하므로 여기서는 텍스트/이미지 반영만 한다)
    open func configure(with content: NativeAdContent) {}

    /// 광고가 없을 때(no-fill/로드 전) 표시할 기본 콘텐츠를 구성한다.
    open func configureDefaultContent() {}
}
