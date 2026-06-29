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
        .executable(name: "BatchOperationsBenchmark", targets: ["BatchOperationsBenchmark"]),
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
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.3.0-1/SFCGAL.xcframework.zip",
            checksum: "93bffa35aeee2bdc6ba31cb9790ef3cccb1723762e28d4d78a8a7ee9be5f694e"
        ),
        .binaryTarget(
            name: "CGMP_Binary",
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.3.0-1/GMP.xcframework.zip",
            checksum: "fa4539b69863524f90ec9a6116e6a25a7425e7f04f365f8f7018c410cb566b53"
        ),
        .binaryTarget(
            name: "CMPFR_Binary",
            url: "https://github.com/Postert/SFCGAL_SPM/releases/download/v2.3.0-1/MPFR.xcframework.zip",
            checksum: "3078911fc4d9e5a3238a323a8d7eb60ebca4051b2acdb88544e7ecdd2079bd13"
        ),

        // ── Tests ──
        .executableTarget(
            name: "BatchOperationsBenchmark",
            dependencies: ["SwiftSFCGAL"],
            path: "Benchmarks/BatchOperationsBenchmark"
        ),

        .testTarget(name: "SwiftSFCGALTests", dependencies: ["SwiftSFCGAL", "CSFCGAL_Shim"]),
    ]
)
