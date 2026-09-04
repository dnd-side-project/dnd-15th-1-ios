import SharedDesignSystem
import SharedLogger
import SharedUtils
import SwiftUI
import ThirdPartyUI
import UIKit

/// 화면이 쓰는 카카오 지도 뷰.
public struct KakaoMapView: View {
    @Binding public var camera: MapCamera
    public var pins: [MapPin]
    public var routes: [MapRoute]
    public var userLocation: Coordinate?
    public var onPinTap: (String) -> Void
    public var onMapTap: () -> Void
    /// 접힘 시트 윗면의 화면 전체(global) 좌표 y.
    /// 이 뷰가 화면 전체를 덮는다고 가정한다. 목표 좌표를 이 값의 `focusRatio` 지점에 놓는다.
    /// `0` 이면 화면 한가운데에 그대로 둔다
    public var collapsedSheetTop: CGFloat

    public init(
        camera: Binding<MapCamera>,
        pins: [MapPin] = [],
        routes: [MapRoute] = [],
        userLocation: Coordinate? = nil,
        onPinTap: @escaping (String) -> Void = { _ in },
        onMapTap: @escaping () -> Void = {},
        collapsedSheetTop: CGFloat = 0
    ) {
        _camera = camera
        self.pins = pins
        self.routes = routes
        self.userLocation = userLocation
        self.onPinTap = onPinTap
        self.onMapTap = onMapTap
        self.collapsedSheetTop = collapsedSheetTop
    }

    public var body: some View {
        KakaoMapRepresentable(
            camera: $camera,
            pins: pins,
            routes: routes,
            userLocation: userLocation,
            onPinTap: onPinTap,
            onMapTap: onMapTap,
            collapsedSheetTop: collapsedSheetTop
        )
    }
}

/// 카카오 지도 선언형 래퍼.
///
/// `KakaoMap`, `MapPoint`, `Poi` 같은 SDK 타입은 이 파일 밖으로 나가지 않는다.
/// 핀·경로선·현재위치는 값 배열로 넘기고, 카메라만 양방향으로 묶는다.
struct KakaoMapRepresentable: UIViewRepresentable {
    @Binding var camera: MapCamera
    var pins: [MapPin]
    var routes: [MapRoute]
    var userLocation: Coordinate?
    var onPinTap: (String) -> Void
    var onMapTap: () -> Void
    /// 접힘 시트 윗면의 화면 전체(global) 좌표 y.
    /// 이 뷰가 화면 전체를 덮는다고 가정한다. 목표 좌표를 이 값의 `focusRatio` 지점에 놓는다.
    /// `0` 이면 화면 한가운데에 그대로 둔다
    var collapsedSheetTop: CGFloat

    init(
        camera: Binding<MapCamera>,
        pins: [MapPin] = [],
        routes: [MapRoute] = [],
        userLocation: Coordinate? = nil,
        onPinTap: @escaping (String) -> Void = { _ in },
        onMapTap: @escaping () -> Void = {},
        collapsedSheetTop: CGFloat = 0
    ) {
        _camera = camera
        self.pins = pins
        self.routes = routes
        self.userLocation = userLocation
        self.onPinTap = onPinTap
        self.onMapTap = onMapTap
        self.collapsedSheetTop = collapsedSheetTop
    }

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

        coordinator.onPinTap = onPinTap
        coordinator.onMapTap = onMapTap
        coordinator.onCameraChanged = { binding.wrappedValue = $0 }
        coordinator.apply(
            camera: camera,
            pins: pins,
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

extension KakaoMapRepresentable {
    @MainActor
    final class Coordinator: NSObject {
        var onPinTap: (String) -> Void = { _ in }
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
        private var desiredPins: [MapPin] = []
        private var desiredRoutes: [MapRoute] = []
        private var desiredUserLocation: Coordinate?
        private var desiredCollapsedSheetTop: CGFloat = 0

        private var appliedCamera: MapCamera?
        private var appliedPins: [MapPin]?
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
            pins: [MapPin],
            routes: [MapRoute],
            userLocation: Coordinate?,
            collapsedSheetTop: CGFloat
        ) {
            desiredCamera = camera
            desiredPins = pins
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

            if desiredPins != appliedPins {
                drawPins(map)
                appliedPins = desiredPins
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
            appliedPins = nil
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
            routeManager.addRouteStyleSet(KakaoMapRepresentable.makeRouteStyleSet())
            _ = routeManager.addRouteLayer(layerID: Layout.routeLayerID, zOrder: 1_000)
        }

        /// 같은 routeID 는 clear 뒤에도 SDK 가 다시 받지 않는다.
        /// 그래서 안 쓸 경로는 지우지 않고 숨기고, 쓸 경로만 갱신하거나 새로 넣는다
        private func drawRoutes(_ map: KakaoMap) {
            let manager = map.getRouteManager()
            guard let layer = manager.getRouteLayer(layerID: Layout.routeLayerID) else {
                Logger.shared.error(
                    "경로 레이어 조회 실패. layer=\(Layout.routeLayerID)",
                    category: .feature
                )
                return
            }

            let routesToDraw = desiredRoutes.filter { $0.coordinates.count > 1 }
            let desiredIDs = Set(routesToDraw.map(\.id))

            // 지우면 같은 id 를 다시 못 쓴다
            let obsoleteIDs = (layer.getAllRoutes() ?? [])
                .map(\.routeID)
                .filter { !desiredIDs.contains($0) }
            if obsoleteIDs.isEmpty == false {
                layer.hideRoutes(routeIDs: obsoleteIDs)
            }

            for route in routesToDraw {
                let segments = [
                    RouteSegment(points: route.coordinates.map(\.mapPoint), styleIndex: 0),
                ]
                if let existing = layer.getRoute(routeID: route.id) {
                    existing.changeStyleAndData(styleID: Layout.routeStyleID, segments: segments)
                    existing.show()
                } else {
                    let options = RouteOptions(
                        routeID: route.id,
                        styleID: Layout.routeStyleID,
                        zOrder: 0
                    )
                    options.segments = segments
                    if let addedRoute = layer.addRoute(option: options) {
                        addedRoute.show()
                    } else {
                        Logger.shared.error(
                            "경로 추가 실패. route=\(route.id)",
                            category: .feature
                        )
                    }
                }
            }
        }

        private func drawUserLocation(_ map: KakaoMap) {
            let manager = map.getLabelManager()
            guard let layer = manager.getLabelLayer(layerID: Layout.userLocationLayerID) else {
                Logger.shared.error(
                    "사용자 위치 레이어 조회 실패. layer=\(Layout.userLocationLayerID)",
                    category: .feature
                )
                return
            }

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

        private func registerPinStyleIfNeeded(
            pin: MapPin,
            manager: LabelManager
        ) {
            let styleID = pin.styleID
            guard !registeredPoiStyleIDs.contains(styleID) else { return }

            let style = pin.makeStyle()
            manager.addPoiStyle(
                PoiStyle(
                    styleID: styleID,
                    styles: [
                        PerLevelPoiStyle(
                            iconStyle: PoiIconStyle(
                                symbol: style.image,
                                anchorPoint: style.anchorPoint
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
                                symbol: userLocationImage(),
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
private extension KakaoMapRepresentable.Coordinator {
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

// MARK: - 핀

private extension KakaoMapRepresentable.Coordinator {
    /// 엔진이 막 준비됐을 때만 레이어를 비운다.
    /// 그 다음부터는 바뀐 핀만 더하거나 지운다. 고를 때마다 전부 지워 다시 찍으면
    /// 카메라가 움직이는 동안 핀이 사라진다
    func drawPins(_ map: KakaoMap) {
        let manager = map.getLabelManager()
        guard let layer = manager.getLabelLayer(layerID: KakaoMapRepresentable.Layout.markerLayerID) else {
            Logger.shared.error(
                "마커 레이어 조회 실패. layer=\(KakaoMapRepresentable.Layout.markerLayerID)",
                category: .feature
            )
            return
        }

        if appliedPins == nil {
            layer.clearAllItems()
            for pin in desiredPins {
                addPin(pin, on: layer, manager: manager)
            }
            layer.setClickable(true)
            return
        }

        let change = MapPinDiff.change(from: appliedPins ?? [], to: desiredPins)
        for id in change.removedIDs {
            layer.removePoi(poiID: id)
        }
        for pin in change.added {
            addPin(pin, on: layer, manager: manager)
        }
        for pin in change.moved {
            layer.getPoi(poiID: pin.id)?
                .moveAt(pin.coordinate.mapPoint, duration: 0)
        }
        for pin in change.restyled {
            registerPinStyleIfNeeded(pin: pin, manager: manager)
            guard let poi = layer.getPoi(poiID: pin.id) else { continue }
            poi.changeStyle(styleID: pin.styleID, enableTransition: false)
            poi.rank = pin.rank
        }
        layer.setClickable(true)
    }

    func addPin(
        _ pin: MapPin,
        on layer: LabelLayer,
        manager: LabelManager
    ) {
        registerPinStyleIfNeeded(pin: pin, manager: manager)
        let options = PoiOptions(styleID: pin.styleID, poiID: pin.id)
        options.clickable = true
        options.rank = pin.rank
        layer.addPoi(option: options, at: pin.coordinate.mapPoint)?.show()
    }
}

// MARK: - 카메라

private extension KakaoMapRepresentable.Coordinator {
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

extension KakaoMapRepresentable.Coordinator: @preconcurrency MapControllerDelegate {
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

extension KakaoMapRepresentable.Coordinator: @preconcurrency KakaoMapEventDelegate {
    func poiDidTapped(kakaoMap: KakaoMap, layerID: String, poiID: String, position: MapPoint) {
        guard layerID == KakaoMapRepresentable.Layout.markerLayerID else { return }
        onPinTap(poiID)
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

private extension KakaoMapRepresentable {
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
                        width: MapPinImage.pixels(Layout.routeWidth),
                        color: routeColor,
                        strokeWidth: MapPinImage.pixels(Layout.routeStrokeWidth),
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
                pattern: routeDotImage(diameter: Layout.routeDotDiameter),
                distance: MapPinImage.pixels(Layout.routeDotSpacing),
                symbol: nil,
                pinStart: false,
                pinEnd: false
            )
        )
        return styleSet
    }
}

// MARK: - 경로·현재위치 심볼

private let routeColor = SharedDesignSystemAsset.brandPrimary.color
let userLocationColor = UIColor(red: 0.16, green: 0.47, blue: 0.96, alpha: 1.0)

func userLocationImage() -> UIImage {
    MapPinImage.circle(diameter: 18, fill: userLocationColor)
}

// 경로선 위에 일정 간격으로 찍히는 점. SDK 가 선을 따라 반복해 그린다
private func routeDotImage(diameter: CGFloat) -> UIImage {
    let size = CGSize(width: diameter, height: diameter)
    let format = UIGraphicsImageRendererFormat()
    format.scale = MapPinImage.scale

    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor.white.setFill()
        context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
    }
}

// MARK: - 좌표 변환

private extension Coordinate {
    var mapPoint: MapPoint {
        MapPoint(longitude: longitude, latitude: latitude)
    }
}
