// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "CleanMyScreen",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CleanMyScreen", targets: ["CleanMyScreen"])
    ],
    targets: [
        .target(
            name: "CleanMyScreenKit",
            path: "Sources/CleanMyScreenKit"
        ),
        .executableTarget(
            name: "CleanMyScreen",
            dependencies: ["CleanMyScreenKit"],
            path: "Sources/CleanMyScreen"
        ),
        .testTarget(
            name: "CleanMyScreenKitTests",
            dependencies: ["CleanMyScreenKit"],
            path: "Tests/CleanMyScreenKitTests",
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        )
    ]
)
