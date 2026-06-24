// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CloudTunnel",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CloudTunnel",
            path: "Sources/CloudTunnel"
        )
    ]
)
