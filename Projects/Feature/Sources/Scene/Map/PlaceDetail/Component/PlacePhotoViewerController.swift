import SharedDesignSystem
import SwiftUI
import UIKit

/// 전체 화면 사진 뷰어 본체. 시안 「지도사진 상세」: 검은 배경, 왼쪽 위 이름, 오른쪽 위 닫기, 양옆 화살표, 아래 점 줄.
/// 가로 페이징 컬렉션 뷰의 칸마다 확대용 스크롤 뷰가 있다(`PlacePhotoZoomCell`).
/// 확대한 동안에는 좌우 스와이프 넘김과 아래로 쓸어 닫기를 끈다. 화살표는 확대를 풀고 넘긴다.
/// 열 때와 닫을 때 스스로 흐려진다. 감싸는 쪽은 전체 화면 덮개의 애니메이션을 끄고 띄운다
final class PlacePhotoViewerController: UIViewController {
    private let urls: [URL]
    private let titleText: String
    private let onPageChanged: (Int) -> Void
    private let onClose: () -> Void

    private var currentIndex: Int
    private var didScrollToInitialPage = false
    private var didFadeIn = false

    private let layout = UICollectionViewFlowLayout()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let previousButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let dotsView = PlacePhotoDotsView()
    private lazy var dismissPan = UIPanGestureRecognizer(
        target: self,
        action: #selector(handleDismissPan(_:))
    )
    private let backgroundColor = UIColor(Color.gray900)

    /// - Parameters:
    ///   - urls: 연 순간의 사진 목록
    ///   - initialIndex: 처음 보일 사진 순번
    ///   - title: 왼쪽 위 이름. 실제 장소 이름이다
    ///   - onPageChanged: 넘기는 도중 화면 절반을 넘겨 지금 사진이 바뀌면 부른다
    ///   - onClose: 닫기 애니메이션이 끝난 뒤 부른다
    init(
        urls: [URL],
        initialIndex: Int,
        title: String,
        onPageChanged: @escaping (Int) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.urls = urls
        self.currentIndex = min(max(initialIndex, 0), max(urls.count - 1, 0))
        self.titleText = title
        self.onPageChanged = onPageChanged
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = backgroundColor
        view.alpha = 0
        // 감싸는 덮개는 상태 표시줄을 희게 하려고 어두운 모드다. 뷰어 안은 앱과 같은 밝은 모드로 둔다
        overrideUserInterfaceStyle = .light
        setUpCollectionView()
        setUpChrome()
        dismissPan.delegate = self
        // 두 손가락 확대를 시작하는 순간은 아직 확대 전이라 `gestureRecognizerShouldBegin` 이 못 막는다
        dismissPan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(dismissPan)
        updateChrome()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = collectionView.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        if layout.itemSize != size {
            layout.itemSize = size
            layout.invalidateLayout()
        }
        guard !didScrollToInitialPage else { return }
        collectionView.layoutIfNeeded()
        collectionView.contentOffset = CGPoint(x: CGFloat(currentIndex) * size.width, y: 0)
        // 첫 자리에 놓기 전 0 위치의 스크롤 알림이 순번을 0 으로 되돌리지 않게, 놓은 뒤부터 따라간다
        didScrollToInitialPage = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didFadeIn else { return }
        didFadeIn = true
        UIView.animate(withDuration: PlacePhotoViewerMetric.fadeDuration) { [weak self] in
            self?.view.alpha = 1
        }
    }
}

// MARK: - 배치

private extension PlacePhotoViewerController {
    var currentCell: PlacePhotoZoomCell? {
        collectionView.cellForItem(at: IndexPath(item: currentIndex, section: 0)) as? PlacePhotoZoomCell
    }

    /// 쓸어 내리는 동안 함께 흐려지는 화면 위 장식들
    var chromeViews: [UIView] {
        [titleLabel, closeButton, previousButton, nextButton, dotsView]
    }

    func setUpCollectionView() {
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        collectionView.backgroundColor = .clear
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = false
        collectionView.isDirectionalLockEnabled = true
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            PlacePhotoZoomCell.self,
            forCellWithReuseIdentifier: PlacePhotoZoomCell.reuseIdentifier
        )
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    func setUpChrome() {
        let typography = Typography.title3SB
        titleLabel.attributedText = NSAttributedString(
            string: titleText,
            attributes: [
                .font: typography.uiFont,
                .foregroundColor: UIColor(Color.commonWhite),
                .kern: typography.tracking,
            ]
        )
        titleLabel.lineBreakMode = .byTruncatingTail
        configure(closeButton, image: SharedDesignSystemAsset.x.image, label: "닫기", action: #selector(closeTapped))
        configureArrow(
            previousButton,
            image: SharedDesignSystemAsset.chevronLeft.image,
            label: "이전 사진",
            action: #selector(previousTapped)
        )
        configureArrow(
            nextButton,
            image: SharedDesignSystemAsset.chevronRight.image,
            label: "다음 사진",
            action: #selector(nextTapped)
        )
        for chrome in chromeViews {
            chrome.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(chrome)
        }
        activateChromeConstraints()
    }

    func activateChromeConstraints() {
        let guide = view.safeAreaLayoutGuide
        let closeSize = PlacePhotoViewerMetric.closeButtonSize
        let arrowSize = PlacePhotoViewerMetric.arrowButtonSize
        NSLayoutConstraint.activate([
            // 시안의 제목 줄(높이 40)은 상태 표시줄 바로 아래에서 시작한다
            closeButton.topAnchor.constraint(equalTo: guide.topAnchor),
            closeButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -Spacing.s12),
            closeButton.widthAnchor.constraint(equalToConstant: closeSize),
            closeButton.heightAnchor.constraint(equalToConstant: closeSize),
            titleLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: Spacing.s20),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -Spacing.s8),
            previousButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: Spacing.s8),
            previousButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: arrowSize),
            previousButton.heightAnchor.constraint(equalToConstant: arrowSize),
            nextButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -Spacing.s8),
            nextButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: arrowSize),
            nextButton.heightAnchor.constraint(equalToConstant: arrowSize),
            dotsView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dotsView.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -Spacing.s12),
        ])
    }

    func configure(_ button: UIButton, image: UIImage, label: String, action: Selector) {
        button.setImage(image.withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = UIColor(Color.commonWhite)
        button.accessibilityLabel = label
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    /// 시안의 양옆 화살표: 반투명 검은 원(36) 안에 20 크기 화살표
    func configureArrow(_ button: UIButton, image: UIImage, label: String, action: Selector) {
        let iconSize = PlacePhotoViewerMetric.arrowIconSize
        let resized = UIGraphicsImageRenderer(size: CGSize(width: iconSize, height: iconSize)).image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: iconSize, height: iconSize))
        }
        configure(button, image: resized, label: label, action: action)
        button.backgroundColor = UIColor(Color.dimBackground)
            .withAlphaComponent(PlacePhotoViewerMetric.arrowBackgroundAlpha)
        button.layer.cornerRadius = PlacePhotoViewerMetric.arrowButtonSize / 2
        button.clipsToBounds = true
    }
}

// MARK: - 넘김·닫기

private extension PlacePhotoViewerController {
    func updateChrome() {
        let arrows = PlacePhotoPaging.arrows(count: urls.count, current: currentIndex)
        previousButton.isHidden = !arrows.showsPrevious
        nextButton.isHidden = !arrows.showsNext
        dotsView.update(dots: PlacePhotoPaging.dots(count: urls.count, current: currentIndex))
    }

    /// 지금 사진을 확대한 동안에는 좌우 스와이프로 넘기지 않는다
    func updateInteraction() {
        collectionView.isScrollEnabled = currentCell?.isZoomed != true
    }

    /// 화면 절반을 넘긴 자리로 지금 사진을 정하고 리듀서에 알린다. 같은 사진이면 아무것도 안 한다
    func syncPage() {
        let width = collectionView.bounds.width
        guard didScrollToInitialPage, width > 0, !urls.isEmpty else { return }
        let page = min(max(Int((collectionView.contentOffset.x / width).rounded()), 0), urls.count - 1)
        guard page != currentIndex else { return }
        currentIndex = page
        updateChrome()
        updateInteraction()
        onPageChanged(page)
    }

    func move(to index: Int) {
        let width = collectionView.bounds.width
        guard urls.indices.contains(index), width > 0 else { return }
        currentCell?.resetZoom()
        collectionView.setContentOffset(CGPoint(x: CGFloat(index) * width, y: 0), animated: true)
    }

    @objc func previousTapped() {
        move(to: currentIndex - 1)
    }

    @objc func nextTapped() {
        move(to: currentIndex + 1)
    }

    @objc func closeTapped() {
        UIView.animate(withDuration: PlacePhotoViewerMetric.fadeDuration) { [weak self] in
            self?.view.alpha = 0
        } completion: { [weak self] _ in
            self?.onClose()
        }
    }

    /// 사진이 손을 따라 내려가고, 정한 거리를 넘겨 놓으면 닫힌다. 못 넘기면 제자리로 돌아온다
    @objc func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        let offset = max(0, gesture.translation(in: view).y)
        switch gesture.state {
        case .began:
            // 함께 잡힌 좌우 넘김을 끊는다
            collectionView.isScrollEnabled = false
        case .changed:
            applyDismissProgress(offset: offset)
        case .ended:
            if offset > PlacePhotoViewerMetric.dismissDistance {
                finishDismiss()
            } else {
                cancelDismiss()
            }
        case .cancelled, .failed:
            cancelDismiss()
        default:
            break
        }
    }

    func applyDismissProgress(offset: CGFloat) {
        let progress = min(offset / PlacePhotoViewerMetric.dismissFadeDistance, 1)
        collectionView.transform = CGAffineTransform(translationX: 0, y: offset)
        view.backgroundColor = backgroundColor.withAlphaComponent(1 - progress)
        for chrome in chromeViews {
            chrome.alpha = 1 - progress
        }
    }

    func finishDismiss() {
        UIView.animate(withDuration: PlacePhotoViewerMetric.fadeDuration) { [weak self] in
            guard let self else { return }
            collectionView.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
            view.backgroundColor = backgroundColor.withAlphaComponent(0)
            for chrome in chromeViews {
                chrome.alpha = 0
            }
        } completion: { [weak self] _ in
            self?.onClose()
        }
    }

    func cancelDismiss() {
        UIView.animate(withDuration: PlacePhotoViewerMetric.fadeDuration) { [weak self] in
            self?.applyDismissProgress(offset: 0)
        } completion: { [weak self] _ in
            self?.updateInteraction()
        }
    }
}

// MARK: - 컬렉션 뷰

extension PlacePhotoViewerController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        urls.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PlacePhotoZoomCell.reuseIdentifier,
            for: indexPath
        )
        guard let photoCell = cell as? PlacePhotoZoomCell else { return cell }
        photoCell.configure(url: urls[indexPath.item])
        photoCell.onZoomChanged = { [weak self] in
            self?.updateInteraction()
        }
        return photoCell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        // 화면 밖으로 나간 사진은 확대를 푼다. 돌아오면 처음 크기다
        (cell as? PlacePhotoZoomCell)?.resetZoom()
    }

    // 칸 안의 확대 스크롤 뷰는 칸이 델리게이트라 여기로 오지 않는다. 이 알림은 컬렉션 뷰 것뿐이다
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncPage()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        syncPage()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        syncPage()
    }
}

// MARK: - 쓸어 닫기 손짓

extension PlacePhotoViewerController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === dismissPan else { return true }
        // 확대한 동안에는 사진 안에서 움직이는 손짓이라 닫지 않는다
        guard currentCell?.isZoomed != true else { return false }
        let velocity = dismissPan.velocity(in: view)
        return velocity.y > 0 && abs(velocity.y) > abs(velocity.x)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // 컬렉션 뷰·칸의 스크롤 손짓이 먼저 잡아도 아래로 내리는 손짓은 받는다. 받으면 `.began` 이 넘김을 끊는다
        gestureRecognizer === dismissPan
    }
}

private enum PlacePhotoViewerMetric {
    static let closeButtonSize: CGFloat = 40
    static let arrowButtonSize: CGFloat = 36
    static let arrowIconSize: CGFloat = 20
    /// 시안 원 배경 #111111 60%. `dimBackground` 는 같은 색 80% 라 투명도만 바꾼다
    static let arrowBackgroundAlpha: CGFloat = 0.6
    /// 이만큼 넘겨 놓으면 닫힌다
    static let dismissDistance: CGFloat = 120
    /// 이만큼 내리면 배경과 장식이 다 흐려진다
    static let dismissFadeDistance: CGFloat = 300
    static let fadeDuration: TimeInterval = 0.2
}
