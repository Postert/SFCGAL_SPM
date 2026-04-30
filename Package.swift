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
        .binaryTarget(
            name: "CSFCGAL_Binary",
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.2.0-4/SFCGAL.xcframework.zip",
            checksum: "7f76e423bde3763926b794570bdcb0694a66c05833626fae5a10394989f9ad43"
        ),
        .binaryTarget(
            name: "CGMP_Binary",
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.2.0-4/GMP.xcframework.zip",
            checksum: "596bfe1c24e2adb1b5c3985c10e8adbe42ab1a20953ebee29a177f77ed705e88"
        ),
        .binaryTarget(
            name: "CMPFR_Binary",
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.2.0-4/MPFR.xcframework.zip",
            checksum: "0c18ad701fb95bae2488dbea744d81034242b1eaa61079b50bf142ff2317758b"
        ),
        .binaryTarget(
            name: "CBoostSerialization_Binary",
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.2.0-4/BoostSerialization.xcframework.zip",
            checksum: "31b794fdbca52c40601d11d166b2277b71cabde72684d7f6e1fdbe627f00db82"
        ),

        // ── Tests ──
        .testTarget(name: "SwiftSFCGALTests", dependencies: ["SwiftSFCGAL", "CSFCGAL_Shim"]),
    ]
)
