import Foundation
import Testing
@testable import SwiftSFCGAL

enum UpstreamParity {
    static let pointTypeID: UInt32 = 1
    static let lineStringTypeID: UInt32 = 2
    static let polygonTypeID: UInt32 = 3
    static let multiPointTypeID: UInt32 = 4
    static let multiLineStringTypeID: UInt32 = 5
    static let multiPolygonTypeID: UInt32 = 6
    static let geometryCollectionTypeID: UInt32 = 7
    static let polyhedralSurfaceTypeID: UInt32 = 15
    static let triangulatedSurfaceTypeID: UInt32 = 16
    static let triangleTypeID: UInt32 = 17
    static let solidTypeID: UInt32 = 101
    static let multiSolidTypeID: UInt32 = 102

    static let epsilon = 1e-9

    static func geometry(_ wkt: String) throws -> Geometry {
        TestSupport.initializeSFCGALOnce()
        return try Geometry.fromWKT(wkt)
    }

    static func point(_ wkt: String) throws -> Point {
        try #require(geometry(wkt) as? Point)
    }

    static func lineString(_ wkt: String) throws -> LineString {
        try #require(geometry(wkt) as? LineString)
    }

    static func polygon(_ wkt: String) throws -> Polygon {
        try #require(geometry(wkt) as? Polygon)
    }

    static func triangle(_ wkt: String) throws -> Triangle {
        try #require(geometry(wkt) as? Triangle)
    }

    static func collection(_ wkt: String) throws -> GeometryCollection {
        try #require(geometry(wkt) as? GeometryCollection)
    }

    static func almostEqual(_ a: Double,
                            _ b: Double,
                            tolerance: Double = epsilon) -> Bool {
        abs(a - b) <= tolerance
    }

    static func expectAlmostEqual(_ actual: Double,
                                  _ expected: Double,
                                  tolerance: Double = epsilon,
                                  _ message: String = "") {
        #expect(almostEqual(actual, expected, tolerance: tolerance), Comment(rawValue: message))
    }

    static func expectWKT(_ geometry: Geometry,
                          decimals: Int32,
                          equals expected: String,
                          _ upstream: String) {
        #expect(geometry.asWKT(decimals: decimals) == expected, Comment(rawValue: upstream))
    }

    static func expectEmptyWKT(_ geometry: Geometry,
                               equals expected: String,
                               _ upstream: String) {
        #expect(geometry.asWKT(decimals: 1) == expected, Comment(rawValue: upstream))
    }

    static func expectRoundTripsWKB(_ geometry: Geometry,
                                    decimals: Int32 = 6,
                                    _ upstream: String = "") throws {
        let parsed = try Geometry.fromWKB(geometry.asWKB())
        #expect(parsed.geometryTypeID == geometry.geometryTypeID, Comment(rawValue: upstream))
        #expect(parsed.asWKT(decimals: decimals) == geometry.asWKT(decimals: decimals),
                Comment(rawValue: upstream))
    }

    static func expectRoundTripsHexWKB(_ geometry: Geometry,
                                       decimals: Int32 = 6,
                                       _ upstream: String = "") throws {
        let parsed = try Geometry.fromHexWKB(geometry.asHexWKB())
        #expect(parsed.geometryTypeID == geometry.geometryTypeID, Comment(rawValue: upstream))
        #expect(parsed.asWKT(decimals: decimals) == geometry.asWKT(decimals: decimals),
                Comment(rawValue: upstream))
    }

    static func squareShellWKT(min: Double = 0.0, max: Double = 1.0) -> String {
        """
        SOLID Z (
          (
            ((\(min) \(min) \(min),\(min) \(max) \(min),\(max) \(max) \(min),\(max) \(min) \(min),\(min) \(min) \(min))),
            ((\(min) \(min) \(max),\(max) \(min) \(max),\(max) \(max) \(max),\(min) \(max) \(max),\(min) \(min) \(max))),
            ((\(min) \(min) \(min),\(max) \(min) \(min),\(max) \(min) \(max),\(min) \(min) \(max),\(min) \(min) \(min))),
            ((\(max) \(min) \(min),\(max) \(max) \(min),\(max) \(max) \(max),\(max) \(min) \(max),\(max) \(min) \(min))),
            ((\(min) \(max) \(min),\(min) \(max) \(max),\(max) \(max) \(max),\(max) \(max) \(min),\(min) \(max) \(min))),
            ((\(min) \(min) \(min),\(min) \(min) \(max),\(min) \(max) \(max),\(min) \(max) \(min),\(min) \(min) \(min)))
          )
        )
        """
    }

    static func upstreamCubeSolidWKT() -> String {
        """
        SOLID (
          (
            ((0 0 0,0 1 0,1 1 0,1 0 0,0 0 0)),
            ((0 0 0,0 0 1,0 1 1,0 1 0,0 0 0)),
            ((0 0 0,1 0 0,1 0 1,0 0 1,0 0 0)),
            ((1 1 1,0 1 1,0 0 1,1 0 1,1 1 1)),
            ((1 1 1,1 0 1,1 0 0,1 1 0,1 1 1)),
            ((1 1 1,1 1 0,0 1 0,0 1 1,1 1 1))
          )
        )
        """
    }

    static func upstreamCubeWithHoleSolidWKT() -> String {
        """
        SOLID (
          (
            ((0 0 0,0 0 1,0 1 1,0 1 0,0 0 0)),
            ((0 0 0,0 1 0,1 1 0,1 0 0,0 0 0)),
            ((0 0 0,1 0 0,1 0 1,0 0 1,0 0 0)),
            ((1 0 0,1 1 0,1 1 1,1 0 1,1 0 0)),
            ((0 0 1,1 0 1,1 1 1,0 1 1,0 0 1)),
            ((0 1 0,0 1 1,1 1 1,1 1 0,0 1 0))
          ),
          (
            ((0.2 0.2 0.2,0.2 0.8 0.2,0.2 0.8 0.8,0.2 0.2 0.8,0.2 0.2 0.2)),
            ((0.2 0.2 0.2,0.8 0.2 0.2,0.8 0.8 0.2,0.2 0.8 0.2,0.2 0.2 0.2)),
            ((0.2 0.2 0.2,0.2 0.2 0.8,0.8 0.2 0.8,0.8 0.2 0.2,0.2 0.2 0.2)),
            ((0.8 0.2 0.2,0.8 0.2 0.8,0.8 0.8 0.8,0.8 0.8 0.2,0.8 0.2 0.2)),
            ((0.2 0.2 0.8,0.2 0.8 0.8,0.8 0.8 0.8,0.8 0.2 0.8,0.2 0.2 0.8)),
            ((0.2 0.8 0.2,0.8 0.8 0.2,0.8 0.8 0.8,0.2 0.8 0.8,0.2 0.8 0.2))
          )
        )
        """
    }

    static func cubePolyhedralSurfaceWKT(min: Double = 0.0, max: Double = 1.0) -> String {
        """
        POLYHEDRALSURFACE Z (
          ((\(min) \(min) \(min),\(min) \(max) \(min),\(max) \(max) \(min),\(max) \(min) \(min),\(min) \(min) \(min))),
          ((\(min) \(min) \(max),\(max) \(min) \(max),\(max) \(max) \(max),\(min) \(max) \(max),\(min) \(min) \(max))),
          ((\(min) \(min) \(min),\(max) \(min) \(min),\(max) \(min) \(max),\(min) \(min) \(max),\(min) \(min) \(min))),
          ((\(max) \(min) \(min),\(max) \(max) \(min),\(max) \(max) \(max),\(max) \(min) \(max),\(max) \(min) \(min))),
          ((\(min) \(max) \(min),\(min) \(max) \(max),\(max) \(max) \(max),\(max) \(max) \(min),\(min) \(max) \(min))),
          ((\(min) \(min) \(min),\(min) \(min) \(max),\(min) \(max) \(max),\(min) \(max) \(min),\(min) \(min) \(min)))
        )
        """
    }
}
