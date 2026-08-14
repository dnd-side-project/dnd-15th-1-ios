#if DEBUG
import Foundation
import ObjectiveC
import SharedUtils
import ThirdPartyUI

/// 프리뷰 프로세스에서만 `NSBundle` 을 스위즐해, `Bundle.main` 의 `.bundle` 탐색 결과에
/// 카카오 지도 리소스 번들 경로를 덧붙이고 `Bundle.main` 의 번들 ID 를 앱 것으로 바꾼다.
/// 카카오 SDK 가 리소스를 `Bundle.main` 에서만 찾고(`KakaoMapPreviewSupport.hasResourceBundle` 참고),
/// 앱 키 인증이 번들 ID 에 묶여 있어서다. `XCODE_RUNNING_FOR_PREVIEWS == "1"` 인 프로세스에서만 설치된다.
enum KakaoMapPreviewBundleShim {
    static func activateIfNeeded() {
        activateCalled = true
        _ = activation
    }

    static let resolvedBundlePath: String? = locateKakaoBundle()

    private static let activation: Void = {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" else {
            activationSkipReason = "env != \"1\""
            return
        }
        guard resolvedBundlePath != nil else {
            activationSkipReason = "kakao bundle not found"
            return
        }
        // fallbackAppKey 지연 초기화가 설치 후 처음 돌면 스위즐된 Bundle 메서드로
        // 재진입할 수 있어, 스위즐이 읽을 값은 설치 전에 확정한다.
        overrideBundleIdentifier = fallbackAppKey?.bundleIdentifier
        installSwizzle()
    }()

    // MARK: - 진단 (프리뷰 자리표시자에 스크린샷으로 읽기 위한 상태 노출)
    //
    // nonisolated(unsafe) static var 쓰기 계약: 스위즐 설치 전 초기화 경로에서만 쓴다.
    // 설치 후에는 스위즐된 메서드가 임의 스레드에서 읽으므로 읽기 전용이다.

    private struct CandidateProbe {
        let path: String
        let reason: String
    }

    nonisolated(unsafe) private(set) static var activateCalled = false
    nonisolated(unsafe) private(set) static var activationSkipReason: String?
    nonisolated(unsafe) private(set) static var swizzleInstalled = false
    nonisolated(unsafe) private(set) static var swizzleFailureReason: String?
    nonisolated(unsafe) fileprivate static var overrideBundleIdentifier: String?
    nonisolated(unsafe) private static var probes: [CandidateProbe] = []

    static var diagnostics: [String] {
        var lines: [String] = []

        let env = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"]
        lines.append("ENV XCODE_RUNNING_FOR_PREVIEWS = \(env.map { "\"\($0)\"" } ?? "(unset)")")

        lines.append("activateIfNeeded called: \(activateCalled)")
        var swizzleLine = "swizzle installed: \(swizzleInstalled)"
        if let reason = activationSkipReason {
            swizzleLine += " (skipped: \(reason))"
        }
        if let reason = swizzleFailureReason {
            swizzleLine += " (failed: \(reason))"
        }
        lines.append(swizzleLine)

        // resolvedBundlePath 를 먼저 읽어 탐색(과 probes 기록)을 강제한다.
        if let found = resolvedBundlePath {
            lines.append("kakao bundle FOUND: \(abbreviate(found))")
        } else {
            lines.append("kakao bundle NOT FOUND, \(probes.count) candidates probed:")
            for probe in probes.prefix(5) {
                lines.append("• [\(probe.reason)] \(abbreviate(probe.path))")
            }
            if probes.count > 5 {
                lines.append("• … and \(probes.count - 5) more")
            }
        }

        let mainPaths = Bundle.main.paths(forResourcesOfType: "bundle", inDirectory: nil)
        let kakaoIncluded = resolvedBundlePath.map(mainPaths.contains) ?? false
        lines.append("Bundle.main *.bundle count: \(mainPaths.count), kakao included: \(kakaoIncluded)")

        // 앱 키는 값은 절대 찍지 않고 출처만 찍는다.
        if AppInfo.string(.kakaoNativeAppKey) != nil {
            lines.append("appKey: AppInfo")
        } else if let fallback = fallbackAppKey {
            lines.append("appKey: fallback(\(fallback.appName))")
        } else {
            lines.append("appKey: NOT FOUND")
        }

        let overridden = swizzleInstalled && overrideBundleIdentifier != nil
        lines.append(
            "Bundle.main.bundleIdentifier: \(Bundle.main.bundleIdentifier ?? "(nil)")"
                + (overridden ? " (overridden)" : "")
        )

        return lines
    }

    private static func abbreviate(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    // MARK: - 번들 탐색

    private static let kakaoBundleName = "KakaoMapsSDK-SPM_KakaoMapsSDK-SPM.bundle"

    /// SDK 가 리소스 번들을 식별할 때 쓰는 표식 파일 경로의 단일 원천.
    /// `KakaoMapPreviewSupport.resourceMarker` 가 확장자만 떼어 재사용한다.
    static let markerRelativePath = "assets/KakaoMapsSDKBundle.plist"

    /// 번들은 `Bundle.main` 에는 없어도 빌드 산출물 디렉터리 근처에는 있다.
    /// 후보를 넓게 잡고, 표식 파일을 가진 `.bundle` 을 처음 만나는 순간 확정한다.
    private static func locateKakaoBundle() -> String? {
        let fileManager = FileManager.default
        var visited = Set<String>()

        for directory in candidateDirectories() {
            let directoryPath = directory.standardizedFileURL.path
            guard visited.insert(directoryPath).inserted else { continue }

            if directory.lastPathComponent == kakaoBundleName, isKakaoBundle(directory) {
                return directoryPath
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: directoryPath, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else {
                probes.append(CandidateProbe(path: directoryPath, reason: "no dir"))
                continue
            }

            let direct = directory.appendingPathComponent(kakaoBundleName)
            if isKakaoBundle(direct) {
                return direct.path
            }
            if fileManager.fileExists(atPath: direct.path) {
                probes.append(CandidateProbe(path: directoryPath, reason: "bundle exists, marker missing"))
                continue
            }

            let entries = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            let bundleEntries = entries.filter { $0.pathExtension == "bundle" }
            for entry in bundleEntries where isKakaoBundle(entry) {
                return entry.path
            }
            probes.append(
                CandidateProbe(
                    path: directoryPath,
                    reason: "no kakao (\(bundleEntries.count) other .bundle)"
                )
            )
        }
        return nil
    }

    private static func isKakaoBundle(_ bundleURL: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: bundleURL.appendingPathComponent(markerRelativePath).path
        )
    }

    private static func candidateDirectories() -> [URL] {
        var directories: [URL] = []

        var sdkURL = Bundle(for: SDKInitializer.self).bundleURL
        directories.append(sdkURL)
        for _ in 0..<3 {
            sdkURL = sdkURL.deletingLastPathComponent()
            directories.append(sdkURL)
        }

        for bundle in Bundle.allBundles + Bundle.allFrameworks {
            directories.append(bundle.bundleURL)
            directories.append(bundle.bundleURL.deletingLastPathComponent())
        }

        let searchPathKeys = [
            "DYLD_FRAMEWORK_PATH",
            "DYLD_LIBRARY_PATH",
            "DYLD_FALLBACK_FRAMEWORK_PATH",
            "DYLD_FALLBACK_LIBRARY_PATH",
        ]
        for key in searchPathKeys {
            guard let value = ProcessInfo.processInfo.environment[key] else { continue }
            directories.append(
                contentsOf: value.split(separator: ":").map { URL(fileURLWithPath: String($0)) }
            )
        }

        return directories
    }

    // MARK: - 앱 키 폴백

    /// 프리뷰 호스트 Info.plist 에 카카오 앱 키가 없을 때, 카카오 번들과 같은 빌드 산출물
    /// 디렉터리의 `*.app` Info.plist 에서 같은 키를 찾아 쓰는 폴백. 키 값은 진단에 노출하지 않는다.
    static let fallbackAppKey: FallbackAppInfo? = locateFallbackAppKey()

    struct FallbackAppInfo {
        let value: String
        let appName: String
        let bundleIdentifier: String?
    }

    private static func locateFallbackAppKey() -> FallbackAppInfo? {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" else {
            return nil
        }
        guard let bundlePath = resolvedBundlePath else { return nil }

        let fileManager = FileManager.default
        var directory = URL(fileURLWithPath: bundlePath).deletingLastPathComponent()

        // 번들이 산출물 루트가 아니라 하위(PackageFrameworks 등)에서 찾힌 경우에 대비해 위로 올라가며 훑는다.
        for _ in 0..<3 {
            let entries =
                (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for entry in entries where entry.pathExtension == "app" {
                guard
                    let appBundle = Bundle(url: entry),
                    let raw = appBundle.object(
                        forInfoDictionaryKey: InfoPlistKey.kakaoNativeAppKey.rawValue
                    ) as? String
                else { continue }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let identifier =
                    (appBundle.object(forInfoDictionaryKey: kCFBundleIdentifierKey as String) as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                return FallbackAppInfo(
                    value: trimmed,
                    appName: entry.lastPathComponent,
                    bundleIdentifier: (identifier?.isEmpty == false) ? identifier : nil
                )
            }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }

    // MARK: - 스위즐

    /// 번들 ID 오버라이드는 `bundleIdentifier` getter 하나만 바꾸는 최소 우회다
    /// (`objectForInfoDictionaryKey:` · `infoDictionary` 는 건드리지 않는다).
    /// 모든 교체는 `Bundle.main` 에 대한 결과에만 개입한다.
    private static func installSwizzle() {
        let pairs: [(original: Selector, swizzled: Selector)] = [
            (
                #selector(
                    Bundle.paths(forResourcesOfType:inDirectory:)
                        as (Bundle) -> (String?, String?) -> [String]
                ),
                #selector(Bundle.dulpickPreviewShimPaths(forResourcesOfType:inDirectory:))
            ),
            (
                #selector(getter: Bundle.bundleIdentifier),
                #selector(getter: Bundle.dulpickPreviewShimBundleIdentifier)
            ),
        ]

        // 메서드 조회가 전부 성공했을 때만 일괄 교체한다. 부분 교체 상태를 만들지 않기 위해서다.
        var resolved: [(original: Method, swizzled: Method)] = []
        for pair in pairs {
            guard
                let originalMethod = class_getInstanceMethod(Bundle.self, pair.original),
                let swizzledMethod = class_getInstanceMethod(Bundle.self, pair.swizzled)
            else {
                swizzleFailureReason = "class_getInstanceMethod returned nil for \(pair.original)"
                return
            }
            resolved.append((original: originalMethod, swizzled: swizzledMethod))
        }

        for pair in resolved {
            method_exchangeImplementations(pair.original, pair.swizzled)
        }
        swizzleInstalled = true
    }
}

extension Bundle {
    /// 스위즐된 구현 안에서 같은 셀렉터를 다시 부르는 것은 교체된 원본 구현 호출이다(무한 재귀 아님).
    @objc fileprivate dynamic func dulpickPreviewShimPaths(
        forResourcesOfType ext: String?,
        inDirectory subpath: String?
    ) -> [String] {
        var paths = dulpickPreviewShimPaths(forResourcesOfType: ext, inDirectory: subpath)
        guard
            self === Bundle.main,
            // subpath 지정 탐색은 번들 루트 탐색이 아니므로 개입하지 않는다.
            subpath?.isEmpty ?? true,
            ext?.lowercased() == "bundle",
            let kakaoPath = KakaoMapPreviewBundleShim.resolvedBundlePath,
            !paths.contains(kakaoPath)
        else { return paths }

        paths.append(kakaoPath)
        return paths
    }

    @objc fileprivate dynamic var dulpickPreviewShimBundleIdentifier: String? {
        if self === Bundle.main,
           let identifier = KakaoMapPreviewBundleShim.overrideBundleIdentifier {
            return identifier
        }
        return dulpickPreviewShimBundleIdentifier
    }
}
#endif
