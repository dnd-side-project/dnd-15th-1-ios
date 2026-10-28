import CoreImageCache
import SharedDesignSystem
import SwiftUI
import UIKit

/// 사진 뷰어의 사진 한 장 칸. 확대용 스크롤 뷰 안에 사진을 잘리지 않게 맞춰 가운데 둔다.
/// 사진은 원본 해상도로 받아 확대해도 흐려지지 않는다. 두 손가락과 두 번 탭으로 확대한다
final class PlacePhotoZoomCell: UICollectionViewCell {
    static let reuseIdentifier = "PlacePhotoZoomCell"

    /// 확대 배율이 바뀔 때 부른다. 뷰어가 좌우 넘김을 켜고 끈다
    var onZoomChanged: (() -> Void)?

    /// 처음 맞춘 크기보다 크게 보고 있는지
    var isZoomed: Bool {
        scrollView.zoomScale > scrollView.minimumZoomScale + PlacePhotoZoomMetric.zoomTolerance
    }

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let failureView = UIImageView(image: SharedDesignSystemAsset.error.image)
    private var url: URL?
    private var loadTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 확대 중에 다시 맞추면 보던 자리가 튄다. 처음 크기일 때만 맞춘다
        guard !isZoomed else { return }
        fitImage()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        url = nil
        onZoomChanged = nil
        imageView.image = nil
        failureView.isHidden = true
        resetZoom()
    }

    /// 사진 주소를 받아 원본을 받는다. 받는 동안 스피너, 실패하면 가운데 에러 아이콘이다
    func configure(url: URL) {
        self.url = url
        loadTask?.cancel()
        imageView.image = nil
        failureView.isHidden = true
        spinner.startAnimating()
        loadTask = Task { [weak self] in
            let image = try? await RemoteImageLoader.originalImage(url: url)
            guard !Task.isCancelled else { return }
            self?.show(image, for: url)
        }
    }

    /// 확대를 풀고 처음 크기로 맞춘다
    func resetZoom() {
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        fitImage()
    }
}

private extension PlacePhotoZoomCell {
    func setUp() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = PlacePhotoZoomMetric.maximumZoomScale
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast
        scrollView.frame = contentView.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)

        spinner.color = UIColor(Color.commonWhite)
        spinner.hidesWhenStopped = true
        failureView.isHidden = true
        let centered: [UIView] = [spinner, failureView]
        for view in centered {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
            NSLayoutConstraint.activate([
                view.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                view.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ])
        }

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }

    func show(_ image: UIImage?, for url: URL) {
        // 받는 사이 다른 사진 칸으로 다시 쓰였으면 버린다
        guard self.url == url else { return }
        spinner.stopAnimating()
        imageView.image = image
        failureView.isHidden = image != nil
        resetZoom()
    }

    /// 사진을 칸 안에 잘리지 않게 맞추고 가운데 둔다. 배율 1 이 이 크기다
    func fitImage() {
        let bounds = scrollView.bounds.size
        guard let image = imageView.image,
              bounds.width > 0, bounds.height > 0,
              image.size.width > 0, image.size.height > 0 else {
            imageView.frame = CGRect(origin: .zero, size: bounds)
            scrollView.contentSize = bounds
            scrollView.contentInset = .zero
            return
        }
        let ratio = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let fitted = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        imageView.frame = CGRect(origin: .zero, size: fitted)
        scrollView.contentSize = fitted
        centerImage()
        scrollView.contentOffset = CGPoint(x: -scrollView.contentInset.left, y: -scrollView.contentInset.top)
    }

    /// 사진이 칸보다 작은 쪽은 여백을 반씩 나눠 가운데 둔다
    func centerImage() {
        let bounds = scrollView.bounds.size
        let content = imageView.frame.size
        let horizontal = max(0, (bounds.width - content.width) / 2)
        let vertical = max(0, (bounds.height - content.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    /// 확대 중이면 처음 크기로, 아니면 누른 자리를 가운데로 확대한다
    @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if isZoomed {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            return
        }
        let scale = PlacePhotoZoomMetric.doubleTapZoomScale
        let point = gesture.location(in: imageView)
        let size = CGSize(width: scrollView.bounds.width / scale, height: scrollView.bounds.height / scale)
        let rect = CGRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        scrollView.zoom(to: rect, animated: true)
    }
}

extension PlacePhotoZoomCell: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
        onZoomChanged?()
    }
}

private enum PlacePhotoZoomMetric {
    static let maximumZoomScale: CGFloat = 3
    static let doubleTapZoomScale: CGFloat = 2.5
    static let zoomTolerance: CGFloat = 0.01
}
