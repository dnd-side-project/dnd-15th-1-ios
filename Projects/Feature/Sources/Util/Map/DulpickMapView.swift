import Domain
import SharedDesignSystem
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
    /// 접힘 시트 윗면의 화면 전체(global) 좌표 y.
    /// 이 뷰가 화면 전체를 덮는다고 가정한다. 목표 좌표를 이 값의 `focusRatio` 지점에 놓는다.
    /// `0` 이면 화면 한가운데에 그대로 둔다
    var collapsedSheetTop: CGFloat = 0

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
            userLocation: userLocation,
            collapsedSheetTop: collapsedSheetTop
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
        /// 링크를 놓으면 요청도 사라진다. 지도가 살아 있는 동안 붙잡는다
        private var frameRateLink: UIUpdateLink?
        private var isMapReady = false

        /// SDK 가 마지막으로 통보한 컨테이너 크기. 지도 뷰 생성 전에도 올 수 있어 들고 있는다
        private var containerSize: CGSize?

        private var desiredCamera: MapCamera
        private var desiredMarkers: [MapMarker] = []
        private var desiredRoutes: [MapRoute] = []
        private var desiredUserLocation: Coordinate?
        private var desiredCollapsedSheetTop: CGFloat = 0

        private var appliedCamera: MapCamera?
        private var appliedMarkers: [MapMarker]?
        private var appliedRoutes: [MapRoute]?
        private var appliedUserLocation: Coordinate?
        private var appliedCollapsedSheetTop: CGFloat = 0

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
            // 가변 주사율이 낮은 값으로 내려앉으면 프레임 간격이 고르지 않다.
            // 실기기에서 이 링크를 빼면 평균 73.8Hz 가 58.5Hz 로, 프레임 떨굼이 35% 에서 54% 로 나빠졌다.
            // minimum 이 이 링크가 맡는 일이다. 범위는 요청이라 시스템이 다른 요청과 함께 고른다
            let frameRateLink = UIUpdateLink(view: container)
            frameRateLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            frameRateLink.isEnabled = true
            self.frameRateLink = frameRateLink
            self.controller = controller
            controller.prepareEngine()
            controller.activateEngine()
            observeAppLifecycle()
        }

        func teardown() {
            stopObservingAppLifecycle()
            frameRateLink?.isEnabled = false
            frameRateLink = nil
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
            userLocation: Coordinate?,
            collapsedSheetTop: CGFloat
        ) {
            desiredCamera = camera
            desiredMarkers = markers
            desiredRoutes = routes
            desiredUserLocation = userLocation
            desiredCollapsedSheetTop = collapsedSheetTop
            render()
        }

        private var mapView: KakaoMap? {
            controller?.getView(Layout.viewName) as? KakaoMap
        }

        private func render() {
            guard isMapReady, let map = mapView else { return }

            if desiredCamera != appliedCamera || desiredCollapsedSheetTop != appliedCollapsedSheetTop {
                moveCamera(map, to: desiredCamera)
                appliedCamera = desiredCamera
                appliedCollapsedSheetTop = desiredCollapsedSheetTop
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
            appliedCollapsedSheetTop = 0
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
            routeManager.addRouteStyleSet(DulpickMapView.makeRouteStyleSet())
            _ = routeManager.addRouteLayer(layerID: Layout.routeLayerID, zOrder: 1_000)
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

// MARK: - 마커

private extension DulpickMapView.Coordinator {
    /// 엔진이 막 준비됐을 때만 레이어를 비운다.
    /// 그 다음부터는 바뀐 핀만 더하거나 지운다. 고를 때마다 전부 지워 다시 찍으면
    /// 카메라가 움직이는 동안 핀이 사라진다
    func drawMarkers(_ map: KakaoMap) {
        let manager = map.getLabelManager()
        guard let layer = manager.getLabelLayer(layerID: DulpickMapView.Layout.markerLayerID) else { return }

        if appliedMarkers == nil {
            layer.clearAllItems()
            for marker in desiredMarkers {
                addMarker(marker, on: layer, manager: manager)
            }
            layer.setClickable(true)
            return
        }

        let change = MapMarkerDiff.change(from: appliedMarkers ?? [], to: desiredMarkers)
        for id in change.removedIDs {
            layer.removePoi(poiID: id)
        }
        for marker in change.added {
            addMarker(marker, on: layer, manager: manager)
        }
        for marker in change.moved {
            layer.getPoi(poiID: marker.id)?
                .moveAt(marker.coordinate.mapPoint, duration: 0)
        }
        for marker in change.restyled {
            let styleID = MapMarkerSymbol.styleID(for: marker.kind)
            registerMarkerStyleIfNeeded(
                styleID: styleID,
                kind: marker.kind,
                manager: manager
            )
            guard let poi = layer.getPoi(poiID: marker.id) else { continue }
            poi.changeStyle(styleID: styleID, enableTransition: false)
            poi.rank = MapMarkerSymbol.rank(for: marker.kind)
        }
        layer.setClickable(true)
    }

    func addMarker(
        _ marker: MapMarker,
        on layer: LabelLayer,
        manager: LabelManager
    ) {
        let styleID = MapMarkerSymbol.styleID(for: marker.kind)
        registerMarkerStyleIfNeeded(styleID: styleID, kind: marker.kind, manager: manager)
        let options = PoiOptions(styleID: styleID, poiID: marker.id)
        options.clickable = true
        options.rank = MapMarkerSymbol.rank(for: marker.kind)
        layer.addPoi(option: options, at: marker.coordinate.mapPoint)?.show()
    }
}

// MARK: - 카메라

private extension DulpickMapView.Coordinator {
    func moveCamera(_ map: KakaoMap, to camera: MapCamera) {
        let update = CameraUpdate.make(
            target: focusedCenter(map, to: camera),
            zoomLevel: camera.zoomLevel,
            mapView: map
        )
        map.animateCamera(
            cameraUpdate: update,
            options: CameraAnimationOptions(
                autoElevation: ObjCBool(MapCameraMove.autoElevation),
                consecutive: false,
                durationInMillis: MapCameraMove.durationInMillis
            )
        )
    }

    /// 접힘 시트 윗면 대비 초점 지점의 자리.
    ///
    /// 절반이 아니다. 검색바와 카테고리 칩이 지도 위쪽을 덮어, 온전히 보이는 띠의
    /// 한가운데가 그보다 아래다. 아이폰 14 기준 칩 바닥 139pt ~ 시트 윗면 464pt 의
    /// 한가운데가 302pt 이고 그것이 시트 윗면의 0.65 다 (2026-08-21 실측)
    private static let focusRatio: CGFloat = 0.65

    /// 초점 지점의 y. 시트 윗면이 안 왔거나 뷰 밖이면 화면 한가운데다
    private func focusY(in rect: CGRect) -> CGFloat {
        guard desiredCollapsedSheetTop > 0, desiredCollapsedSheetTop <= rect.height else {
            return rect.midY
        }
        return desiredCollapsedSheetTop * Self.focusRatio
    }

    /// 목표 좌표가 시트 위 영역의 한가운데에 보이도록 카메라 중심을 남쪽으로 민다.
    ///
    /// 지도를 먼저 옮겨 재면 화면이 한 번 튄다. 그래서 **지금 자리에서** 픽셀당 위도를 재고,
    /// 줌이 다르면 한 단계에 두 배인 성질로 환산한다.
    private func focusedCenter(_ map: KakaoMap, to camera: MapCamera) -> MapPoint {
        let target = camera.center
        let rect = map.viewRect
        let focusY = focusY(in: rect)
        // 초점이 화면 한가운데면 오프셋이 0 이므로 목표 좌표를 그대로 돌려준다
        guard focusY != rect.midY else {
            return target.mapPoint
        }

        let centerLatitude = map.getPosition(CGPoint(x: rect.midX, y: rect.midY)).wgsCoord.latitude
        let focusLatitude = map.getPosition(CGPoint(x: rect.midX, y: focusY)).wgsCoord.latitude

        // 줌이 한 단계 오르면 같은 픽셀이 덮는 위도 폭이 절반이 된다
        let scale = pow(2.0, Double(map.zoomLevel - camera.zoomLevel))
        let offset = (centerLatitude - focusLatitude) * scale

        return Coordinate(
            latitude: target.latitude + offset,
            longitude: target.longitude
        ).mapPoint
    }

    func reportCamera(of map: KakaoMap) {
        let rect = map.viewRect
        let focusY = focusY(in: rect)
        let focus = map.getPosition(CGPoint(x: rect.midX, y: focusY)).wgsCoord
        let updated = MapCamera(
            center: Coordinate(latitude: focus.latitude, longitude: focus.longitude),
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

/// 카카오 지도 SDK 는 입력 px 에 `UIScreen.main.scale / 2` 를 곱한다.
/// 2x 기준으로 넘기면 기기와 관계없이 의도한 pt 가 된다
private enum KakaoMapMetrics {
    static let imageScale: CGFloat = 2

    static func pixels(_ points: UInt) -> UInt {
        UInt(CGFloat(points) * imageScale)
    }

    static func pixels(_ points: CGFloat) -> Float {
        Float(points * imageScale)
    }
}

private extension DulpickMapView {
    enum Layout {
        static let viewName = "dulpick.map"
        static let markerLayerID = "dulpick.map.marker"
        static let userLocationLayerID = "dulpick.map.userLocation"
        static let userLocationStyleID = "dulpick.map.style.userLocation"
        static let routeLayerID = "dulpick.map.route"
        static let routeStyleID = "dulpick.map.style.route"
        /// 시안 c01. 물방울 폭 26 을 자로 재면 칠이 약 4
        static let routeWidth: UInt = 4
        /// 시안 c01. 흰 외곽은 칠의 한 쪽 약 1
        static let routeStrokeWidth: UInt = 1
        /// 선 두께(4)보다 작아 선 안에 들어간다
        static let routeDotDiameter: CGFloat = 2.2
        static let routeDotSpacing: CGFloat = 35
    }

    static func makeRouteStyleSet() -> RouteStyleSet {
        let styleSet = RouteStyleSet(
            styleID: Layout.routeStyleID,
            styles: [
                RouteStyle(styles: [
                    PerLevelRouteStyle(
                        width: KakaoMapMetrics.pixels(Layout.routeWidth),
                        color: MapMarkerSymbol.routeColor,
                        strokeWidth: KakaoMapMetrics.pixels(Layout.routeStrokeWidth),
                        strokeColor: .white,
                        level: 0,
                        patternIndex: 0
                    ),
                ]),
            ]
        )
        // 시작·끝을 고정하면 번호 핀과 겹친다. 짧은 구간은 SDK 가 가운데에 하나 두는지 실기기에서 본다
        styleSet.addPattern(
            RoutePattern(
                pattern: MapMarkerSymbol.routeDotImage(diameter: Layout.routeDotDiameter),
                distance: KakaoMapMetrics.pixels(Layout.routeDotSpacing),
                symbol: nil,
                pinStart: false,
                pinEnd: false
            )
        )
        return styleSet
    }
}

// MARK: - 기본 마커 심볼

/// `place` 는 여기서 그린 최소 심볼을 쓴다.
/// 고른 장소(`selected`)·코스 후보(`candidate`)·코스 번호(`numbered`)는 `MapPlacePin` 을 얹는다.
/// 저장한 장소 핀(`category`)은 시안 에셋을 20 으로 줄여 쓴다.
@MainActor
enum MapMarkerSymbol {
    static let routeColor = SharedDesignSystemAsset.brandPrimary.color

    private static let placeColor = UIColor(red: 0.98, green: 0.31, blue: 0.44, alpha: 1.0)
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
            rendered(MapPlacePin(content: .number(number)))
        case let .category(category):
            resized(category.pin, to: categoryPinSide)
        case .candidate:
            rendered(MapPlacePin(content: .candidate))
        }
    }

    /// 저장한 장소 핀. 에셋 상자 24 안에 흰 원 20 · 컬러 원 16 이 들어 있고
    /// 남는 자리는 SVG 에 구워진 그림자 몫이다. 상자를 줄이면 안쪽 원도 같이 줄어
    /// 시안(컬러 원 16)과 어긋난다. 그래서 원본 크기 그대로 쓴다
    private static let categoryPinSide: CGFloat = 24

    private static func resized(_ image: UIImage, to side: CGFloat) -> UIImage {
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = KakaoMapMetrics.imageScale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
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
        case .selected, .candidate, .numbered:
            // 그림자 여백만큼 이미지가 커졌다. 1.0 을 주면 끝이 좌표보다 그만큼 위에 앉는다
            CGPoint(x: 0.5, y: (pinShadowInset + pinHeight) / (pinShadowInset * 2 + pinHeight))
        // default 를 쓰지 않는다. 물방울 심볼이 늘면 여기서 컴파일이 막혀야 한다
        case .place, .category:
            CGPoint(x: 0.5, y: 0.5)
        }
    }

    /// SwiftUI 부품을 지도가 받는 `UIImage` 로 굽는다.
    ///
    /// `MapPlacePin` 은 그림자를 달고 있어 프레임 밖으로 잉크가 번진다.
    /// `ImageRenderer` 는 프레임까지만 그리므로 여백을 둘러 잘리지 않게 한다.
    private static func rendered(_ view: some View) -> UIImage {
        let renderer = ImageRenderer(content: view.padding(pinShadowInset))
        renderer.scale = KakaoMapMetrics.imageScale
        return renderer.uiImage ?? UIImage()
    }

    static func userLocationImage() -> UIImage {
        circle(diameter: 18, fill: userLocationColor, text: nil)
    }

    // 경로선 위에 일정 간격으로 찍히는 점. SDK 가 선을 따라 반복해 그린다
    static func routeDotImage(diameter: CGFloat) -> UIImage {
        let size = CGSize(width: diameter, height: diameter)
        let format = UIGraphicsImageRendererFormat()
        format.scale = KakaoMapMetrics.imageScale

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func circle(diameter: CGFloat, fill: UIColor, text: String?) -> UIImage {
        let ringWidth: CGFloat = 3
        let size = CGSize(width: diameter + ringWidth * 2, height: diameter + ringWidth * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = KakaoMapMetrics.imageScale

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
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
    @Previewable @State var camera: MapCamera = .seoulCityHall

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
            userLocation: MapCamera.seoulCityHall.center
        )
        .ignoresSafeArea()
    }
}
#endif
