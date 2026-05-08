import Foundation
import Testing
@testable import SwiftSFCGAL

/// Shared helpers for SwiftSFCGAL tests.
enum TestSupport {
    private static let initializeOnce: Void = {
        initializeSFCGAL()
    }()

    /// Ensures SFCGAL is initialized exactly once for tests that use the Swift
    /// wrapper. Individual shim tests may still call `initializeSFCGAL()`
    /// directly when they need to verify idempotency.
    static func initializeSFCGALOnce() {
        _ = initializeOnce
    }

    static func almostEqual(_ a: Double,
                            _ b: Double,
                            tolerance: Double = 1e-9) -> Bool {
        abs(a - b) <= tolerance
    }

    static func almostEqual(_ a: Float,
                            _ b: Float,
                            tolerance: Float = 1e-5) -> Bool {
        abs(a - b) <= tolerance
    }
}

enum TestGeometry {
    static func fromWKT(_ wkt: String) throws -> Geometry {
        TestSupport.initializeSFCGALOnce()
        return try Geometry.fromWKT(wkt)
    }

    static func unitSquare() throws -> Geometry {
        try fromWKT(GeometryFixtures.Polygons2D.unitSquare)
    }

    static func lShape() throws -> Geometry {
        try fromWKT(GeometryFixtures.Polygons2D.lShape)
    }

    static func squareWithHole() throws -> Geometry {
        try fromWKT(GeometryFixtures.PolygonsWithHoles.squareWithCenteredHole)
    }

    static func verticalWall() throws -> Geometry {
        try fromWKT(GeometryFixtures.Polygons3D.verticalWall)
    }

    static func unitCube() throws -> Geometry {
        try fromWKT(GeometryFixtures.Solids.unitCube)
    }
}

