import ProjectDescription

/// CI 러너에서만 Swift 패키지를 저장소 안 `.derivedData/SourcePackages` 에 받는다.
/// 캐시 복원 단계가 미리 채워 둔 폴더를 xcodebuild 가 그대로 쓰게 하려는 것이다.
/// 매니페스트 프로세스에는 셸 환경 변수가 전달되지 않으므로 Tuist 의 `TUIST_` 통로를 쓴다.
private let packageResolutionArguments: [String] = {
    let workspacePath = Environment.ciWorkspace.getString(default: "")
    guard workspacePath.isEmpty == false else { return [] }
    return ["-clonedSourcePackagesDirPath", "\(workspacePath)/.derivedData/SourcePackages"]
}()

let tuist = Tuist(
    project: .tuist(
        compatibleXcodeVersions: .all,
        generationOptions: .options(
            additionalPackageResolutionArguments: packageResolutionArguments
        )
    )
)
