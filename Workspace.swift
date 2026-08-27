import ProjectDescription
import ProjectDescriptionHelpers

let workspace = Workspace(
    name: ProjectEnvironment.productName,
    projects: Module.workspaceProjectPaths
)
