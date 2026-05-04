// swift-tools-version: 6.2
import Foundation
import PackageDescription

// SkipTCA is a minimal, Skip-Lite-transpilable subset of The Composable
// Architecture. It exists so that shared Swift code can be written against a
// single API surface that builds on iOS *and* transpiles to Kotlin/Compose for
// Android.
//
// The package follows the same INCLUDE_SKIP pattern used by `SharedModels`:
// Skip dependencies and the skipstone plugin are only attached when
// `INCLUDE_SKIP=1` is set in the environment (Android build). On iOS no Skip
// machinery is pulled in at all.
let includeSkipEnv = ProcessInfo.processInfo.environment["INCLUDE_SKIP"]?.lowercased()
let includeSkip = includeSkipEnv == "1" || includeSkipEnv == "true"

var packageDependencies: [Package.Dependency] = []
var targetDependencies: [Target.Dependency] = []
var targetPlugins: [Target.PluginUsage] = []
var targetExclude: [String] = []

if includeSkip {
  packageDependencies += [
    .package(url: "https://source.skip.tools/skip.git", from: "1.2.0"),
    .package(url: "https://source.skip.tools/skip-foundation.git", from: "1.0.0"),
    .package(url: "https://source.skip.tools/skip-model.git", from: "1.0.0"),
  ]
  targetDependencies += [
    .product(name: "SkipFoundation", package: "skip-foundation"),
    .product(name: "SkipModel", package: "skip-model"),
  ]
  targetPlugins += [
    .plugin(name: "skipstone", package: "skip")
  ]
} else {
  targetExclude += ["Skip"]
}

let package = Package(
  name: "skip-tca",
  // Lowest platforms that support `@Observable` (Observation framework) and
  // Swift Testing. Skip Lite supports modern Compose so Android does not
  // bound this further.
  platforms: [.iOS(.v17), .macOS(.v14), .watchOS(.v10), .tvOS(.v17), .visionOS(.v1)],
  products: [
    .library(
      name: "SkipTCA",
      targets: ["SkipTCA"]
    ),
    .library(
      name: "SkipTCATesting",
      targets: ["SkipTCATesting"]
    ),
  ],
  dependencies: packageDependencies,
  targets: [
    .target(
      name: "SkipTCA",
      dependencies: targetDependencies,
      exclude: targetExclude,
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ],
      plugins: targetPlugins
    ),
    .target(
      name: "SkipTCATesting",
      dependencies: ["SkipTCA"],
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ]
    ),
    .testTarget(
      name: "SkipTCATests",
      dependencies: ["SkipTCA", "SkipTCATesting"],
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ]
    ),
  ]
)
