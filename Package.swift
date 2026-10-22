// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "PasseioCerto", products: [.library(name: "PuzzleCore", targets: ["PuzzleCore"])], targets: [.target(name: "PuzzleCore"), .testTarget(name: "PuzzleCoreTests", dependencies: ["PuzzleCore"])])
