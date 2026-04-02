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
                    condition: .when(platforms: [.macOS, .linux])),
                .target(name: "CSFCGAL_Binary",
                    condition: .when(platforms: [.iOS, .tvOS, .watchOS, .visionOS])),
                .target(name: "CGMP_Binary",
                    condition: .when(platforms: [.iOS, .tvOS, .watchOS, .visionOS])),
                .target(name: "CMPFR_Binary",
                    condition: .when(platforms: [.iOS, .tvOS, .watchOS, .visionOS])),
            ]
        ),

        // ── C shim layer (cross-platform, compiled from source) ──
        .target(
            name: "CSFCGAL_Shim",
            dependencies: [
                .target(name: "CSFCGAL_System",
                    condition: .when(platforms: [.macOS, .linux])),
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
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.2.0-1/SFCGAL.xcframework.zip",
            checksum: "1d596bf0cb510005357435f9eefdc332858008f333c74b35ad5dd08be57b8bfe"
        ),
        .binaryTarget(
            name: "CGMP_Binary",
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.2.0-1/GMP.xcframework.zip",
            checksum: "2b3919dae1dcc7ef75e27dc0260d99b16cab331a562e855a40ea86b47ef7527f"
        ),
        .binaryTarget(
            name: "CMPFR_Binary",
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.2.0-1/MPFR.xcframework.zip",
            checksum: "2d58f110d04e9ac7f621c322a65e1cdfa07b2072956b2ced97bc1c685382910a"
        ),

        // ── Tests ──
        .testTarget(name: "SwiftSFCGALTests", dependencies: ["SwiftSFCGAL"]),
    ]
)
