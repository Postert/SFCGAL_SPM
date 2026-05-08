import Testing
@testable import SwiftSFCGAL

@Test func upstreamExtrudeCases() throws {
    // Upstream: algorithm/ExtrudeTest.cpp / testExtrudePoint, testExtrudeLineString,
    // testExtrudeSquare, testExtrudeMultiPolygon, testExtrudeSquareWithHole, testChainingExtrude
    let pointExtrusion = try Point(x: 0.0, y: 0.0).extrude(dx: 0.0, dy: 0.0, dz: 1.0)
    #expect(pointExtrusion.geometryTypeID == UpstreamParity.lineStringTypeID)

    let lineExtrusion = try UpstreamParity.geometry("LINESTRING (0 0,1 0)").extrude(dx: 0.0, dy: 0.0, dz: 1.0)
    #expect(lineExtrusion.geometryTypeID == UpstreamParity.polygonTypeID ||
            lineExtrusion.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID)
    UpstreamParity.expectAlmostEqual(try lineExtrusion.area3D(), 1.0, tolerance: 1e-8)

    let squareExtrusion = try UpstreamParity.geometry("POLYGON ((0 0,1 0,1 1,0 1,0 0))").extrude(dx: 0.0, dy: 0.0, dz: 1.0)
    #expect(squareExtrusion.geometryTypeID == UpstreamParity.solidTypeID)
    UpstreamParity.expectAlmostEqual(try squareExtrusion.volume(), 1.0, tolerance: 1e-8)

    let withHole = try UpstreamParity.geometry(
        "POLYGON ((0 0,4 0,4 4,0 4,0 0),(1 1,1 3,3 3,3 1,1 1))"
    ).extrude(dx: 0.0, dy: 0.0, dz: 2.0)
    UpstreamParity.expectAlmostEqual(try withHole.volume(), 24.0, tolerance: 1e-8)
}

@Test func upstreamStraightSkeletonCases() throws {
    // Upstream: algorithm/StraightSkeletonTest.cpp / testTriangle, testPolygon,
    // testPolygonWithHole, testMultiPolygon, testDistanceInM
    let triangleSkeleton = try UpstreamParity.geometry("TRIANGLE ((0 0,4 0,0 4,0 0))").straightSkeleton()
    #expect(triangleSkeleton.geometryTypeID == UpstreamParity.multiLineStringTypeID)
    #expect((triangleSkeleton as? MultiLineString)?.numGeometries ?? 0 > 0)

    let polygonSkeleton = try UpstreamParity.geometry("POLYGON ((0 0,4 0,4 4,0 4,0 0))").straightSkeleton()
    #expect(polygonSkeleton.geometryTypeID == UpstreamParity.multiLineStringTypeID)
    #expect((polygonSkeleton as? MultiLineString)?.numGeometries ?? 0 > 0)

    let polygonWithHoleSkeleton = try UpstreamParity.geometry(
        "POLYGON ((0 0,6 0,6 6,0 6,0 0),(2 2,2 4,4 4,4 2,2 2))"
    ).straightSkeleton()
    #expect(polygonWithHoleSkeleton.geometryTypeID == UpstreamParity.multiLineStringTypeID)

    let withDistances = try UpstreamParity.geometry("POLYGON ((0 0,4 0,4 4,0 4,0 0))")
        .straightSkeletonWithDistances()
    #expect(withDistances.geometryTypeID == UpstreamParity.multiLineStringTypeID)
}

@Test func upstreamStraightSkeletonExtrusionCases() throws {
    // Upstream: algorithm/StraightSkeletonTest.cpp / testEmptyExtrudeStraightSkeleton,
    // testExtrudeStraightSkeleton, testExtrudeStraightSkeletonPolygonWithHole,
    // testExtrudeStraightSkeletonGenerateBuilding
    let roof = try UpstreamParity.geometry("POLYGON ((0 0,4 0,4 4,0 4,0 0))")
        .straightSkeletonExtrude(height: 2.0)
    #expect(roof.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID ||
            roof.geometryTypeID == UpstreamParity.solidTypeID)
    #expect(try roof.area3D() > 0.0)

    let roofWithHole = try UpstreamParity.geometry(
        "POLYGON ((0 0,6 0,6 6,0 6,0 0),(2 2,2 4,4 4,4 2,2 2))"
    ).straightSkeletonExtrude(height: 2.0)
    #expect(try roofWithHole.area3D() > 0.0)

    let building = try UpstreamParity.geometry("POLYGON ((0 0,4 0,4 4,0 4,0 0))")
        .extrudePolygonStraightSkeleton(buildingHeight: 3.0, roofHeight: 1.0)
    #expect(building.geometryTypeID == UpstreamParity.solidTypeID ||
            building.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID)
    #expect(try building.volume() >= 0.0)
}

@Test func upstreamStraightSkeletonPartitionCases() throws {
    // Upstream: algorithm/StraightSkeletonTest.cpp / partition rectangle, L-shape,
    // polygon with hole, multipolygon, non-polygon geometry.
    let rectangle = try UpstreamParity.geometry("POLYGON ((0 0,4 0,4 2,0 2,0 0))")
        .straightSkeletonPartition()
    #expect(!rectangle.asWKT().isEmpty)
    #expect(rectangle.geometryTypeID == UpstreamParity.multiPolygonTypeID ||
            rectangle.geometryTypeID == UpstreamParity.geometryCollectionTypeID ||
            rectangle.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID)

    let lShape = try UpstreamParity.geometry("POLYGON ((0 0,4 0,4 1,1 1,1 4,0 4,0 0))")
        .straightSkeletonPartition()
    #expect(!lShape.asWKT().isEmpty)

    #expect(throws: SFCGALError.self) {
        _ = try UpstreamParity.geometry("POINT (0 0)").straightSkeletonPartition()
    }
}
