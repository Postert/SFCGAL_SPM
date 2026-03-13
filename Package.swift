// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SFCGAL_SPM",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SFCGAL_SPM",
            targets: ["SFCGAL_SPM"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SFCGAL_SPM"
        ),
        .testTarget(
            name: "SFCGAL_SPMTests",
            dependencies: ["SFCGAL_SPM"]
        ),
    ]
)
