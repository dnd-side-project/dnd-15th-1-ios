import ProjectDescription

/// 모듈 카탈로그.
/// 이름/경로/번들 suffix/의존성 참조를 한곳에서 관리한다.
public enum Module: String, CaseIterable {
    case sharedUtils
    case sharedDesignSystem
    case thirdParty
    case thirdPartyUI
    case thirdPartyCore
    case domain
    case data
    case feature
    case app
    case coreNetwork
    case coreStorage
    case coreLogger

    public var targetName: String {
        switch self {
        case .sharedUtils: return "SharedUtils"
        case .sharedDesignSystem: return "SharedDesignSystem"
        case .thirdParty: return "ThirdParty"
        case .thirdPartyUI: return "ThirdPartyUI"
        case .thirdPartyCore: return "ThirdPartyCore"
        case .domain: return "Domain"
        case .data: return "Data"
        case .feature: return "Feature"
        case .app: return "App"
        case .coreNetwork: return "CoreNetwork"
        case .coreStorage: return "CoreStorage"
        case .coreLogger: return "CoreLogger"
        }
    }

    public var pathString: String {
        switch self {
        case .sharedUtils: return "Projects/Shared/Util"
        case .sharedDesignSystem: return "Projects/Shared/DesignSystem"
        case .thirdParty: return "Projects/ThirdParty/ThirdParty"
        case .thirdPartyUI: return "Projects/ThirdParty/ThirdPartyUI"
        case .thirdPartyCore: return "Projects/ThirdParty/ThirdPartyCore"
        case .domain: return "Projects/Domain"
        case .data: return "Projects/Data"
        case .feature: return "Projects/Feature"
        case .app: return "Projects/App"
        case .coreNetwork: return "Projects/Core/Network"
        case .coreStorage: return "Projects/Core/Storage"
        case .coreLogger: return "Projects/Core/Logger"
        }
    }

    public var path: Path {
        .relativeToRoot(pathString)
    }

    public var bundleIdSuffix: String {
        switch self {
        case .sharedUtils: return "shared.utils"
        case .sharedDesignSystem: return "shared.designsystem"
        case .thirdParty: return "thirdparty"
        case .thirdPartyUI: return "thirdpartyui"
        case .thirdPartyCore: return "thirdpartycore"
        case .domain: return "domain"
        case .data: return "data"
        case .feature: return "feature"
        case .app: return "app"
        case .coreNetwork: return "core.network"
        case .coreStorage: return "core.storage"
        case .coreLogger: return "core.logger"
        }
    }

    public var dependency: TargetDependency {
        .project(target: targetName, path: path)
    }

    /// Workspace에 등록할 모듈 경로 (생성 순서와 무관하게 전체 목록).
    public static var workspaceProjectPaths: [Path] {
        allCases.map(\.path)
    }
}

public extension TargetDependency {
    static var sharedUtils: TargetDependency { Module.sharedUtils.dependency }
    static var sharedDesignSystem: TargetDependency { Module.sharedDesignSystem.dependency }
    static var thirdParty: TargetDependency { Module.thirdParty.dependency }
    static var thirdPartyUI: TargetDependency { Module.thirdPartyUI.dependency }
    static var thirdPartyCore: TargetDependency { Module.thirdPartyCore.dependency }
    static var domain: TargetDependency { Module.domain.dependency }
    static var data: TargetDependency { Module.data.dependency }
    static var feature: TargetDependency { Module.feature.dependency }
    static var coreNetwork: TargetDependency { Module.coreNetwork.dependency }
    static var coreStorage: TargetDependency { Module.coreStorage.dependency }
    static var coreLogger: TargetDependency { Module.coreLogger.dependency }
}
