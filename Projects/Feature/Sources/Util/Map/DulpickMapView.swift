import Domain
import SharedLogger
import SwiftUI
import ThirdPartyUI
import UIKit

/// 카카오 지도 선언형 래퍼.
///
/// `KakaoMap`, `MapPoint`, `Poi` 같은 SDK 타입은 이 파일 밖으로 나가지 않는다.
/// 마커·경로선·현재위치는 값 배열로 넘기고, 카메라만 양방향으로 묶는다.
struct DulpickMapView: UIViewRepresentable {
    @Binding var camera: MapCamera
    var markers: [MapMarker] = []
    var routes: [MapRoute] = []
    var userLocation: Coordinate?
    var onMarkerTap: (String) -> Void = { _ in }
    var onMapTap: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(camera: camera)
    }

    func makeUIView(context: Context) -> KMViewContainer {
        let container = KMViewContainer()
        context.coordinator.prepare(container: container)
        return container
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        let coordinator = context.coordinator
        let binding = $camera

        coordinator.onMarkerTap = onMarkerTap
        coordinator.onMapTap = onMapTap
        coordinator.onCameraChanged = { binding.wrappedValue = $0 }
        coordinator.apply(
            camera: camera,
            markers: markers,
            routes: routes,
            userLocation: userLocation
        )
    }

    static func dismantleUIView(_ uiView: KMViewContainer, coordinator: Coordinator) {
        MainActor.assumeIsolated {
            coordinator.teardown()
        }
    }
}

// MARK: - Coordinator

extension DulpickMapView {
    @MainActor
    final class Coordinator: NSObject {
        var onMarkerTap: (String) -> Void = { _ in }
        var onMapTap: () -> Void = {}
        var onCameraChanged: (MapCamera) -> Void = { _ in }

        private var controller: KMController?
        private weak var container: KMViewContainer?
        private var isMapReady = false

        /// SDK 가 마지막으로 통보한 컨테이너 크기. 지도 뷰 생성 전에도 올 수 있어 들고 있는다
        private var containerSize: CGSize?

        private var desiredCamera: MapCamera
        private var desiredMarkers: [MapMarker] = []
        private var desiredRoutes: [MapRoute] = []
        private var desiredUserLocation: Coordinate?

        private var appliedCamera: MapCamera?
        private var appliedMarkers: [MapMarker]?
        private var appliedRoutes: [MapRoute]?
        private var appliedUserLocation: Coordinate?

        private var registeredPoiStyleIDs: Set<String> = []

        /// 앱 생명주기 알림 토큰. `teardown()` 에서 반드시 해제한다
        private var lifecycleObservers: [NSObjectProtocol] = []

        init(camera: MapCamera) {
            desiredCamera = camera
            super.init()
        }

        // MARK: - 엔진 생명주기

        func prepare(container: KMViewContainer) {
            self.container = container
            let controller = KMController(viewContainer: container)
            controller.delegate = self
            // 120Hz 기기에서 지도가 60Hz 로 묶이는 것을 푼다. SDK 기본값이 false 다
            controller.proMotionSupport = true
            self.controller = controller
            controller.prepareEngine()
            controller.activateEngine()
            observeAppLifecycle()
        }

        func teardown() {
            stopObservingAppLifecycle()
            controller?.pauseEngine()
            controller?.resetEngine()
            controller = nil
            container = nil
            isMapReady = false
            // 엔진을 리셋하면 거기 등록한 스타일과 통보받은 크기도 같이 사라진다.
            // 안 비우면 다음 엔진에 스타일을 다시 등록하지 않는다
            registeredPoiStyleIDs.removeAll()
            containerSize = nil
            invalidateAppliedState()
        }

        // MARK: - 상태 반영

        func apply(
            camera: MapCamera,
            markers: [MapMarker],
            routes: [MapRoute],
            userLocation: Coordinate?
        ) {
            desiredCamera = camera
            desiredMarkers = markers
            desiredRoutes = routes
            desiredUserLocation = userLocation
            render()
        }

        private var mapView: KakaoMap? {
            controller?.getView(Layout.viewName) as? KakaoMap
        }

        private func render() {
            guard isMapReady, let map = mapView else { return }

            if desiredCamera != appliedCamera {
                moveCamera(map, to: desiredCamera)
                appliedCamera = desiredCamera
            }

            if desiredMarkers != appliedMarkers {
                drawMarkers(map)
                appliedMarkers = desiredMarkers
            }

            if desiredRoutes != appliedRoutes {
                drawRoutes(map)
                appliedRoutes = desiredRoutes
            }

            if desiredUserLocation != appliedUserLocation {
                drawUserLocation(map)
                appliedUserLocation = desiredUserLocation
            }
        }

        /// 엔진이 리셋되면 레이어가 비므로 applied 캐시도 전부 무효다.
        /// 호출 지점마다 나열하면 하나씩 빠뜨리게 돼서 여기 한곳에 모아 둔다
        private func invalidateAppliedState() {
            appliedCamera = nil
            appliedMarkers = nil
            appliedRoutes = nil
            appliedUserLocation = nil
        }

        // MARK: - 레이어 그리기

        private func setUpLayers(_ map: KakaoMap) {
            let manager = map.getLabelManager()

            _ = manager.addLabelLayer(
                option: LabelLayerOptions(
                    layerID: Layout.markerLayerID,
                    competitionType: .none,
                    competitionUnit: .symbolFirst,
                    orderType: .rank,
                    zOrder: 10_000
                )
            )
            _ = manager.addLabelLayer(
                option: LabelLayerOptions(
                    layerID: Layout.userLocationLayerID,
                    competitionType: .none,
                    competitionUnit: .symbolFirst,
                    orderType: .rank,
                    zOrder: 20_000
                )
            )

            let routeManager = map.getRouteManager()
            routeManager.addRouteStyleSet(
                RouteStyleSet(
                    styleID: Layout.routeStyleID,
                    styles: [
                        RouteStyle(styles: [
                            PerLevelRouteStyle(
                                width: 14,
                                color: MapMarkerSymbol.routeColor,
                                strokeWidth: 3,
                                strokeColor: .white,
                                level: 0
                            ),
                        ]),
                    ]
                )
            )
            _ = routeManager.addRouteLayer(layerID: Layout.routeLayerID, zOrder: 1_000)
        }

        /// 개수가 수십 개 수준이라 레이어를 통째로 다시 그린다
        private func drawMarkers(_ map: KakaoMap) {
            let manager = map.getLabelManager()
            guard let layer = manager.getLabelLayer(layerID: Layout.markerLayerID) else { return }

            layer.clearAllItems()

            for marker in desiredMarkers {
                let styleID = MapMarkerSymbol.styleID(for: marker.kind)
                registerMarkerStyleIfNeeded(styleID: styleID, kind: marker.kind, manager: manager)

                let options = PoiOptions(styleID: styleID, poiID: marker.id)
                options.clickable = true
                options.rank = MapMarkerSymbol.rank(for: marker.kind)
                layer.addPoi(option: options, at: marker.coordinate.mapPoint)?.show()
            }

            layer.setClickable(true)
        }

        private func drawRoutes(_ map: KakaoMap) {
            let manager = map.getRouteManager()
            guard let layer = manager.getRouteLayer(layerID: Layout.routeLayerID) else { return }

            layer.clearAllRoutes()

            for route in desiredRoutes where route.coordinates.count > 1 {
                let options = RouteOptions(
                    routeID: route.id,
                    styleID: Layout.routeStyleID,
                    zOrder: 0
                )
                options.segments = [
                    RouteSegment(points: route.coordinates.map(\.mapPoint), styleIndex: 0),
                ]
                layer.addRoute(option: options)?.show()
            }
        }

        private func drawUserLocation(_ map: KakaoMap) {
            let manager = map.getLabelManager()
            guard let layer = manager.getLabelLayer(layerID: Layout.userLocationLayerID) else { return }

            layer.clearAllItems()

            guard let userLocation = desiredUserLocation else { return }

            registerUserLocationStyleIfNeeded(manager: manager)

            let options = PoiOptions(
                styleID: Layout.userLocationStyleID,
                poiID: Layout.userLocationStyleID
            )
            options.clickable = false
            layer.addPoi(option: options, at: userLocation.mapPoint)?.show()
        }

        private func registerMarkerStyleIfNeeded(
            styleID: String,
            kind: MapMarker.Kind,
            manager: LabelManager
        ) {
            guard !registeredPoiStyleIDs.contains(styleID) else { return }

            manager.addPoiStyle(
                PoiStyle(
                    styleID: styleID,
                    styles: [
                        PerLevelPoiStyle(
                            iconStyle: PoiIconStyle(
                                symbol: MapMarkerSymbol.image(for: kind),
                                anchorPoint: MapMarkerSymbol.anchorPoint(for: kind)
                            ),
                            level: 0
                        ),
                    ]
                )
            )
            registeredPoiStyleIDs.insert(styleID)
        }

        private func registerUserLocationStyleIfNeeded(manager: LabelManager) {
            guard !registeredPoiStyleIDs.contains(Layout.userLocationStyleID) else { return }

            manager.addPoiStyle(
                PoiStyle(
                    styleID: Layout.userLocationStyleID,
                    styles: [
                        PerLevelPoiStyle(
                            iconStyle: PoiIconStyle(
                                symbol: MapMarkerSymbol.userLocationImage(),
                                anchorPoint: CGPoint(x: 0.5, y: 0.5)
                            ),
                            level: 0
                        ),
                    ]
                )
            )
            registeredPoiStyleIDs.insert(Layout.userLocationStyleID)
        }

        fileprivate func mapDidBecomeReady() {
            guard let map = mapView else { return }

            map.eventDelegate = self
            map.poiClickable = true
            setUpLayers(map)
            applyPendingSize(to: map)

            isMapReady = true
            invalidateAppliedState()
            render()
        }

        /// `containerDidResized(_:)` 는 지도 뷰 생성 전에 오기도 한다.
        /// 그때 놓친 크기를 여기서 반영하지 않으면 SDK 가 1×1 뷰를 그대로 들고 있는다
        private func applyPendingSize(to map: KakaoMap) {
            let size = containerSize ?? container?.bounds.size ?? .zero
            guard size != .zero else { return }

            map.viewRect = CGRect(origin: .zero, size: size)
        }

        fileprivate func addMapView() {
            controller?.addView(
                MapviewInfo(
                    viewName: Layout.viewName,
                    defaultPosition: desiredCamera.center.mapPoint,
                    defaultLevel: desiredCamera.zoomLevel
                )
            )
        }

        fileprivate func resizeMapView(to size: CGSize) {
            containerSize = size
            guard size != .zero else { return }

            mapView?.viewRect = CGRect(origin: .zero, size: size)
        }
    }
}

// MARK: - 앱 생명주기

/// SDK 계약상 엔진은 앱이 active 일 때만 활성 상태여야 한다(`KMController.activateEngine`).
/// 백그라운드에서 계속 렌더하면 iOS 가 백그라운드 GPU 접근을 이유로 앱을 죽인다.
///
/// 화면에서 `scenePhase` 를 받아 넘기는 대신 여기서 직접 듣는다.
/// 이 래퍼를 쓰는 화면이 늘어도 화면마다 엔진 생명주기를 기억할 필요가 없게 하려는 것이다
private extension DulpickMapView.Coordinator {
    func observeAppLifecycle() {
        guard lifecycleObservers.isEmpty else { return }

        let center = NotificationCenter.default
        lifecycleObservers = [
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // `queue: .main` 이라 메인 스레드가 보장된다
                MainActor.assumeIsolated {
                    self?.controller?.pauseEngine()
                }
            },
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.controller?.activateEngine()
                }
            },
        ]
    }

    /// 안 떼면 그대로 누수다. `teardown()` 에서 반드시 부른다
    func stopObservingAppLifecycle() {
        let center = NotificationCenter.default
        for observer in lifecycleObservers {
            center.removeObserver(observer)
        }
        lifecycleObservers.removeAll()
    }
}

// MARK: - 카메라

private extension DulpickMapView.Coordinator {
    func moveCamera(_ map: KakaoMap, to camera: MapCamera) {
        let update = CameraUpdate.make(
            target: camera.center.mapPoint,
            zoomLevel: camera.zoomLevel,
            mapView: map
        )
        map.animateCamera(
            cameraUpdate: update,
            options: CameraAnimationOptions(
                autoElevation: false,
                consecutive: false,
                durationInMillis: 250
            )
        )
    }

    func reportCamera(of map: KakaoMap) {
        let rect = map.viewRect
        let center = map.getPosition(CGPoint(x: rect.midX, y: rect.midY)).wgsCoord
        let updated = MapCamera(
            center: Coordinate(latitude: center.latitude, longitude: center.longitude),
            zoomLevel: map.zoomLevel
        )

        guard updated != appliedCamera else { return }

        appliedCamera = updated
        desiredCamera = updated
        onCameraChanged(updated)
    }
}

// MARK: - SDK delegate

extension DulpickMapView.Coordinator: @preconcurrency MapControllerDelegate {
    func addViews() {
        addMapView()
    }

    func addViewSucceeded(_ viewName: String, viewInfoName: String) {
        mapDidBecomeReady()
    }

    /// 여기서 실패하면 화면은 그냥 빈 채로 남는다. 원인을 남길 곳이 로그뿐이다
    func addViewFailed(_ viewName: String, viewInfoName: String) {
        Logger.shared.error(
            "지도 뷰 추가 실패. view=\(viewName) info=\(viewInfoName)",
            category: .feature
        )
    }

    /// 앱키가 틀리거나 만료되거나 할당량을 넘기면 여기로 온다.
    /// 앱키 값은 남기지 않는다
    func authenticationFailed(_ errorCode: Int, desc: String) {
        Logger.shared.error(
            "카카오 지도 인증 실패. code=\(errorCode) desc=\(desc)",
            category: .feature
        )
    }

    func containerDidResized(_ size: CGSize) {
        resizeMapView(to: size)
    }
}

extension DulpickMapView.Coordinator: @preconcurrency KakaoMapEventDelegate {
    func poiDidTapped(kakaoMap: KakaoMap, layerID: String, poiID: String, position: MapPoint) {
        guard layerID == DulpickMapView.Layout.markerLayerID else { return }
        onMarkerTap(poiID)
    }

    func terrainDidTapped(kakaoMap: KakaoMap, position: MapPoint) {
        onMapTap()
    }

    func cameraDidStopped(kakaoMap: KakaoMap, by: MoveBy) {
        // `.notUserAction` 은 우리가 `moveCamera` 로 옮긴 결과다.
        // 그대로 받으면 화면 중심을 역산한 값이 State 를 덮고 `.cameraChanged` 가 한 번 더 돈다.
        // 사용자가 손으로 민 경우만 되돌려준다
        guard by != .notUserAction else { return }

        reportCamera(of: kakaoMap)
    }
}

// MARK: - 내부 상수

private extension DulpickMapView {
    enum Layout {
        static let viewName = "dulpick.map"
        static let markerLayerID = "dulpick.map.marker"
        static let userLocationLayerID = "dulpick.map.userLocation"
        static let userLocationStyleID = "dulpick.map.style.userLocation"
        static let routeLayerID = "dulpick.map.route"
        static let routeStyleID = "dulpick.map.style.route"
    }
}

// MARK: - 기본 마커 심볼

/// `place` `numbered` 는 여기서 그린 최소 심볼을 쓴다.
/// 고른 장소(`selected`)와 코스 후보(`candidate`)는 `MapPlacePin` 을 얹는다.
/// 저장한 장소 핀(`category`)은 시안 에셋을 20 으로 줄여 쓴다.
@MainActor
private enum MapMarkerSymbol {
    static let routeColor = UIColor(red: 0.98, green: 0.31, blue: 0.44, alpha: 1.0)

    private static let placeColor = UIColor(red: 0.98, green: 0.31, blue: 0.44, alpha: 1.0)
    private static let selectedColor = UIColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1.0)
    private static let userLocationColor = UIColor(red: 0.16, green: 0.47, blue: 0.96, alpha: 1.0)

    /// 그림자 radius 2 + offsetY 1 을 담는 여백
    private static let pinShadowInset: CGFloat = 4

    /// 물방울 높이. `MapPlacePin` 의 피그마 Vector 28 × 31.86 에서 온 값이다
    private static let pinHeight: CGFloat = 31.86

    static func styleID(for kind: MapMarker.Kind) -> String {
        switch kind {
        case .place: "dulpick.map.style.place"
        case .selected: "dulpick.map.style.selected"
        case let .numbered(number): "dulpick.map.style.numbered.\(number)"
        case let .category(category): "dulpick.map.style.category.\(category.rawValue)"
        case .candidate: "dulpick.map.style.candidate"
        }
    }

    static func image(for kind: MapMarker.Kind) -> UIImage {
        switch kind {
        case .place:
            circle(diameter: 22, fill: placeColor, text: nil)
        case .selected:
            rendered(MapPlacePin(content: .selected))
        case let .numbered(number):
            circle(diameter: 28, fill: selectedColor, text: "\(number)")
        case let .category(category):
            resized(category.pin, to: categoryPinSide)
        case .candidate:
            rendered(MapPlacePin(content: .candidate))
        }
    }

    /// 저장한 장소 핀. 에셋은 24 로 그려져 있고 시안 대조에서 20 으로 정했다.
    /// 에셋을 고치면 일곱 카테고리와 다른 화면까지 같이 바뀌어 여기서 줄인다
    private static let categoryPinSide: CGFloat = 20

    private static func resized(_ image: UIImage, to side: CGFloat) -> UIImage {
        let size = CGSize(width: side, height: side)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 같은 자리의 카테고리·장소 배지 위에 고른 핀이 앉는다. rank 가 큰 쪽이 위다.
    static func rank(for kind: MapMarker.Kind) -> Int {
        switch kind {
        case .place, .category:
            0
        case .numbered, .selected, .candidate:
            1
        }
    }

    /// 마커 이미지의 어느 점이 좌표에 놓이는지.
    ///
    /// 원형 마커는 중심이 좌표다. 물방울은 뾰족한 아래 끝이 좌표다.
    static func anchorPoint(for kind: MapMarker.Kind) -> CGPoint {
        switch kind {
        case .selected, .candidate:
            // 그림자 여백만큼 이미지가 커졌다. 1.0 을 주면 끝이 좌표보다 그만큼 위에 앉는다
            CGPoint(x: 0.5, y: (pinShadowInset + pinHeight) / (pinShadowInset * 2 + pinHeight))
        // default 를 쓰지 않는다. 물방울 심볼이 늘면 여기서 컴파일이 막혀야 한다
        case .place, .numbered, .category:
            CGPoint(x: 0.5, y: 0.5)
        }
    }

    /// SwiftUI 부품을 지도가 받는 `UIImage` 로 굽는다.
    ///
    /// `MapPlacePin` 은 그림자를 달고 있어 프레임 밖으로 잉크가 번진다.
    /// `ImageRenderer` 는 프레임까지만 그리므로 여백을 둘러 잘리지 않게 한다.
    private static func rendered(_ view: some View) -> UIImage {
        let renderer = ImageRenderer(content: view.padding(pinShadowInset))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage ?? UIImage()
    }

    static func userLocationImage() -> UIImage {
        circle(diameter: 18, fill: userLocationColor, text: nil)
    }

    private static func circle(diameter: CGFloat, fill: UIColor, text: String?) -> UIImage {
        let ringWidth: CGFloat = 3
        let size = CGSize(width: diameter + ringWidth * 2, height: diameter + ringWidth * 2)

        return UIGraphicsImageRenderer(size: size).image { context in
            let outer = CGRect(origin: .zero, size: size)
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: outer)

            fill.setFill()
            context.cgContext.fillEllipse(in: outer.insetBy(dx: ringWidth, dy: ringWidth))

            guard let text else { return }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: diameter * 0.5, weight: .bold),
                .foregroundColor: UIColor.white,
            ]
            let bounds = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(
                    x: outer.midX - bounds.width / 2,
                    y: outer.midY - bounds.height / 2
                ),
                withAttributes: attributes
            )
        }
    }
}

// MARK: - 좌표 변환

private extension Coordinate {
    var mapPoint: MapPoint {
        MapPoint(longitude: longitude, latitude: latitude)
    }
}

// MARK: - Preview

#if DEBUG
/// `MapView` 프리뷰가 안 쓰는 표면(번호 핀·선택 핀·경로선·현재위치)까지 한 번에 보여준다.
#Preview("코스 마커 + 경로") {
    @Previewable @State var camera: MapCamera = .ansan

    let places = SavedPlace.mocks.prefix(4)

    KakaoMapPreviewContainer {
        DulpickMapView(
            camera: $camera,
            markers: places.enumerated().map { index, saved in
                MapMarker(
                    id: saved.id,
                    coordinate: saved.place.coordinate,
                    kind: index == 0 ? .selected : .numbered(index + 1)
                )
            },
            routes: [
                MapRoute(id: "preview.course", coordinates: places.map(\.place.coordinate)),
            ],
            userLocation: MapCamera.ansan.center
        )
        .ignoresSafeArea()
    }
}
#endif
