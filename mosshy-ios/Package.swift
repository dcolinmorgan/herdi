// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "mosshy",
    platforms: [.iOS(.v17)],
    targets: [
        .executableTarget(
            name: "mosshy",
            path: "Sources"
        )
    ]
)
