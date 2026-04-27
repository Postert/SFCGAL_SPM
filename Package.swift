// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftSFCGAL",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "SwiftSFCGAL", targets: ["SwiftSFCGAL"]),
    ],
    targets: [
        // ── The public Swift API ──
        .target(
            name: "SwiftSFCGAL",
            dependencies: [
                "CSFCGAL_Shim",
                .target(name: "CSFCGAL_System",
                    condition: .when(platforms: [.macOS, .linux, .windows])),
                .target(name: "CSFCGAL_Binary",
                    condition: .when(platforms: [.iOS, .tvOS, .watchOS, .visionOS])),
                .target(name: "CGMP_Binary",
                    condition: .when(platforms: [.iOS, .tvOS, .watchOS, .visionOS])),
                .target(name: "CMPFR_Binary",
                    condition: .when(platforms: [.iOS, .tvOS, .watchOS, .visionOS])),
                .target(name: "CBoostSerialization_Binary",
                    condition: .when(platforms: [.iOS, .tvOS, .watchOS, .visionOS])),
            ]
        ),

        // ── C shim layer (cross-platform, compiled from source) ──
        .target(
            name: "CSFCGAL_Shim",
            dependencies: [
                .target(name: "CSFCGAL_System",
                    condition: .when(platforms: [.macOS, .linux, .windows])),
                .target(name: "CSFCGAL_Binary",
                    condition: .when(platforms: [.iOS, .tvOS, .watchOS, .visionOS])),
            ],
            path: "Sources/CSFCGAL_Shim",
            publicHeadersPath: "include"
        ),

        // ── macOS / Linux: use system-installed SFCGAL ──
        .systemLibrary(
            name: "CSFCGAL_System",
            pkgConfig: "sfcgal",
            providers: [
                .brew(["sfcgal"]),
                .apt(["libsfcgal-dev"]),
            ]
        ),

        // ── iOS: prebuilt XCFrameworks (downloaded from GitHub releases) ──
        // NOTE: All four checksums below must be replaced after running the
        // build-xcframeworks workflow with dev_suffix=4. Until then, SPM will
        // refuse to resolve the package.
        .binaryTarget(
            name: "CSFCGAL_Binary",
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.2.0-4/SFCGAL.xcframework.zip",
            checksum: "0000000000000000000000000000000000000000000000000000000000000000"
        ),
        .binaryTarget(
            name: "CGMP_Binary",
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.2.0-4/GMP.xcframework.zip",
            checksum: "0000000000000000000000000000000000000000000000000000000000000000"
        ),
        .binaryTarget(
            name: "CMPFR_Binary",
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.2.0-4/MPFR.xcframework.zip",
            checksum: "0000000000000000000000000000000000000000000000000000000000000000"
        ),
        .binaryTarget(
            name: "CBoostSerialization_Binary",
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.2.0-4/BoostSerialization.xcframework.zip",
            checksum: "0000000000000000000000000000000000000000000000000000000000000000"
        ),

        // ── Tests ──
        .testTarget(name: "SwiftSFCGALTests", dependencies: ["SwiftSFCGAL", "CSFCGAL_Shim"]),
    ]
)
