// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MyMacTools",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MyMacTools",
            path: "Sources/MyMacTools"
        ),
        // swift-testing 이다. Xcode 없이 명령줄 도구만 있으면 `scripts/test.sh` 로 돌린다
        // (프레임워크 경로를 넘겨야 한다 — docs/plans/test-suite/spec.md).
        .testTarget(
            name: "MyMacToolsTests",
            dependencies: ["MyMacTools"],
            path: "Tests/MyMacToolsTests"
        ),
    ]
)
