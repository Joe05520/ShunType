// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShunType",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ShunType", targets: ["ShunType"]),
        .executable(name: "ShunTypeInputMethod", targets: ["ShunTypeInputMethod"]),
        .executable(name: "ShunTypeCheck", targets: ["ShunTypeCheck"])
    ],
    targets: [
        .target(name: "ShunTypeCore", resources: [.process("Resources")]),
        .executableTarget(name: "ShunType", dependencies: ["ShunTypeCore"], linkerSettings: [.linkedFramework("Carbon")]),
        .executableTarget(name: "ShunTypeInputMethod", dependencies: ["ShunTypeCore"], linkerSettings: [.linkedFramework("InputMethodKit"), .linkedFramework("Carbon")]),
        .executableTarget(name: "ShunTypeCheck", dependencies: ["ShunTypeCore"]),
        .testTarget(name: "ShunTypeCoreTests", dependencies: ["ShunTypeCore"])
    ],
    swiftLanguageModes: [.v5]
)
