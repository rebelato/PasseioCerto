// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "PasseioCerto", platforms: [.macOS(.v13), .iOS(.v17)], products: [.library(name: "PuzzleCore", targets: ["PuzzleCore"])], targets: [.target(name: "PuzzleCore"), .testTarget(name: "PuzzleCoreTests", dependencies: ["PuzzleCore"]), .executableTarget(name: "Calibration", dependencies: ["PuzzleCore"])])
