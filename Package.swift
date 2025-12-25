// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OpencodeIsland",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "OpencodeIsland",
            path: "Sources",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
