// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AccountingCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "AccountingCore", targets: ["AccountingCore"])],
    targets: [
        .target(name: "AccountingCore"),
        .testTarget(name: "AccountingCoreTests", dependencies: ["AccountingCore"])
    ]
)
