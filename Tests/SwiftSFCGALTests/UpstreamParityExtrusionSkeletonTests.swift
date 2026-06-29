import Testing
@testable import SwiftSFCGAL

@Test func upstreamExtrudeCases() throws {
    // Upstream: algorithm/ExtrudeTest.cpp / testExtrudePoint, testExtrudeLineString,
    // testExtrudeSquare, testExtrudePolyhedral, testExtrudeMultiPolygon,
    // testExtrudeSquareWithHole, testChainingExtrude
    let pointExtrusion = try Point(x: 0.0, y: 0.0, z: 0.0).extrude(dx: 0.0, dy: 0.0, dz: 1.0)
    #expect(pointExtrusion.geometryTypeID == UpstreamParity.lineStringTypeID)
    UpstreamParity.expectWKT(pointExtrusion, decimals: 1,
                             equals: "LINESTRING Z (0.0 0.0 0.0,0.0 0.0 1.0)",
                             "ExtrudeTest.cpp / testExtrudePoint")

    let lineExtrusion = try UpstreamParity.geometry("LINESTRING (0 0 0,1 0 0)").extrude(dx: 0.0, dy: 0.0, dz: 1.0)
    #expect(lineExtrusion.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID)
    UpstreamParity.expectWKT(lineExtrusion, decimals: 1,
                             equals: "POLYHEDRALSURFACE Z (((0.0 0.0 0.0,1.0 0.0 0.0,1.0 0.0 1.0,0.0 0.0 1.0,0.0 0.0 0.0)))",
                             "ExtrudeTest.cpp / testExtrudeLineString")
    UpstreamParity.expectAlmostEqual(try lineExtrusion.area3D(), 1.0, tolerance: 1e-8)

    let squareExtrusion = try UpstreamParity.geometry("POLYGON ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))").extrude(dx: 0.0, dy: 0.0, dz: 1.0)
    #expect(squareExtrusion.geometryTypeID == UpstreamParity.solidTypeID)
    let squareSolid = try #require(squareExtrusion as? Solid)
    #expect(squareSolid.numShells == 1)
    #expect(squareSolid.exteriorShell.numPatches == 6)
    UpstreamParity.expectAlmostEqual(try squareExtrusion.volume(), 1.0, tolerance: 1e-8)

    let polyhedralExtrusion = try UpstreamParity.geometry(
        "POLYHEDRALSURFACE (((0 0 0,0 1 0,1 1 0,1 0 0,0 0 0)))"
    ).extrude(dx: 0.0, dy: 0.0, dz: 1.0)
    #expect(polyhedralExtrusion.geometryTypeID == UpstreamParity.solidTypeID)
    #expect((polyhedralExtrusion as? Solid)?.numShells == 1)

    let multiPolygonExtrusion = try UpstreamParity.geometry(
        "MULTIPOLYGON (((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0)),((2 0 0,3 0 0,3 1 0,2 1 0,2 0 0)))"
    ).extrude(dx: 0.0, dy: 0.0, dz: 1.0)
    #expect(multiPolygonExtrusion.geometryTypeID == UpstreamParity.multiSolidTypeID)
    #expect((multiPolygonExtrusion as? MultiSolid)?.numGeometries == 2)

    let withHole = try UpstreamParity.geometry(
        "POLYGON ((0 0,4 0,4 4,0 4,0 0),(1 1,1 3,3 3,3 1,1 1))"
    ).extrude(dx: 0.0, dy: 0.0, dz: 2.0)
    UpstreamParity.expectAlmostEqual(try withHole.volume(), 24.0, tolerance: 1e-8)

    let upstreamHole = try UpstreamParity.geometry(
        "POLYGON ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0),(0.2 0.2 0,0.2 0.8 0,0.8 0.8 0,0.8 0.2 0,0.2 0.2 0))"
    ).extrude(dx: 0.0, dy: 0.0, dz: 1.0)
    #expect(upstreamHole.geometryTypeID == UpstreamParity.solidTypeID)
    #expect((upstreamHole as? Solid)?.exteriorShell.numPatches == 10)

    let first = try Point(x: 0.0, y: 0.0).extrude(dx: 1.0, dy: 0.0, dz: 0.0)
    UpstreamParity.expectWKT(first, decimals: 0,
                             equals: "LINESTRING Z (0 0 0,1 0 0)",
                             "ExtrudeTest.cpp / testChainingExtrude")
    let second = try first.extrude(dx: 0.0, dy: 1.0, dz: 0.0)
    UpstreamParity.expectWKT(second, decimals: 0,
                             equals: "POLYHEDRALSURFACE Z (((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0)))",
                             "ExtrudeTest.cpp / testChainingExtrude")
    let third = try second.extrude(dx: 0.0, dy: 0.0, dz: 1.0)
    #expect(third.geometryTypeID == UpstreamParity.solidTypeID)
}

@Test func upstreamStraightSkeletonCases() throws {
    // Upstream: algorithm/StraightSkeletonTest.cpp / testTriangle, testPolygon,
    // testPolygonWithHole, testMultiPolygon, testDistanceInM
    let upstreamTriangle = try UpstreamParity.geometry("TRIANGLE ((1 1,2 1,2 2,1 1))").straightSkeleton()
    #expect(upstreamTriangle.geometryTypeID == UpstreamParity.multiLineStringTypeID)
    #expect((upstreamTriangle as? MultiLineString)?.numGeometries == 3)
    UpstreamParity.expectWKT(upstreamTriangle, decimals: 1,
                             equals: "MULTILINESTRING ((1.0 1.0,1.7 1.3),(2.0 1.0,1.7 1.3),(2.0 2.0,1.7 1.3))",
                             "StraightSkeletonTest.cpp / testTriangle")

    let upstreamPolygon = try UpstreamParity.geometry("POLYGON ((1 1,11 1,11 11,1 11,1 1))").straightSkeleton()
    #expect(upstreamPolygon.geometryTypeID == UpstreamParity.multiLineStringTypeID)
    #expect((upstreamPolygon as? MultiLineString)?.numGeometries == 4)
    UpstreamParity.expectWKT(upstreamPolygon, decimals: 0,
                             equals: "MULTILINESTRING ((1 1,6 6),(11 1,6 6),(11 11,6 6),(1 11,6 6))",
                             "StraightSkeletonTest.cpp / testPolygon")

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

    let upstreamPolygonWithHoleSkeleton = try UpstreamParity.geometry(
        "POLYGON ((-1.0 -1.0,1.0 -1.0,1.0 1.0,-1.0 1.0,-1.0 -1.0),(-0.5 -0.5,-0.5 0.5,0.5 0.5,-0.5 -0.5))"
    ).straightSkeleton()
    #expect((upstreamPolygonWithHoleSkeleton as? MultiLineString)?.numGeometries == 13)

    let invalidPointSkeleton = try UpstreamParity.geometry("POINT (1 2)").straightSkeleton()
    #expect(invalidPointSkeleton.geometryTypeID == UpstreamParity.multiLineStringTypeID)
    #expect((invalidPointSkeleton as? MultiLineString)?.numGeometries == 0)

    let invalidLineSkeleton = try UpstreamParity.geometry("LINESTRING (0 0,1 1)").straightSkeleton()
    #expect(invalidLineSkeleton.geometryTypeID == UpstreamParity.multiLineStringTypeID)
    #expect((invalidLineSkeleton as? MultiLineString)?.numGeometries == 0)

    let emptyMultiPolygonSkeleton = try UpstreamParity.geometry("MULTIPOLYGON (EMPTY,EMPTY)").straightSkeleton()
    UpstreamParity.expectWKT(emptyMultiPolygonSkeleton, decimals: 1,
                             equals: "MULTILINESTRING EMPTY",
                             "StraightSkeletonTest.cpp / testMultiEmptyEmpty")

    let withDistances = try UpstreamParity.geometry("POLYGON ((0 0,4 0,4 4,0 4,0 0))")
        .straightSkeletonWithDistances()
    #expect(withDistances.geometryTypeID == UpstreamParity.multiLineStringTypeID)

    let upstreamWithDistances = try UpstreamParity.geometry("POLYGON ((0 0,1 0,1 1,0 1,0 0))")
        .straightSkeletonWithDistances()
    UpstreamParity.expectWKT(upstreamWithDistances, decimals: 1,
                             equals: "MULTILINESTRING M ((0.0 0.0 0.0,0.5 0.5 0.5),(1.0 0.0 0.0,0.5 0.5 0.5),(1.0 1.0 0.0,0.5 0.5 0.5),(0.0 1.0 0.0,0.5 0.5 0.5))",
                             "StraightSkeletonTest.cpp / testDistanceInM")
}

@Test func upstreamStraightSkeletonExtrusionCases() throws {
    // Upstream: algorithm/StraightSkeletonTest.cpp / testEmptyExtrudeStraightSkeleton,
    // testExtrudeStraightSkeleton, testExtrudeStraightSkeletonPolygonWithHole,
    // testExtrudeStraightSkeletonGenerateBuilding
    let emptyRoof = try UpstreamParity.geometry("POLYGON EMPTY").straightSkeletonExtrude(height: 2.0)
    UpstreamParity.expectWKT(emptyRoof, decimals: 2,
                             equals: "POLYHEDRALSURFACE EMPTY",
                             "StraightSkeletonTest.cpp / testEmptyExtrudeStraightSkeleton")

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
    let upstreamRectangle = try UpstreamParity.geometry("POLYGON ((0 0,0 2,3 2,3 0,0 0))")
        .straightSkeletonPartition()
    #expect(upstreamRectangle.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID)
    #expect((upstreamRectangle as? PolyhedralSurface)?.numPatches == 4)
    UpstreamParity.expectWKT(upstreamRectangle, decimals: 2,
                             equals: "POLYHEDRALSURFACE (((0.00 0.00,1.00 1.00,0.00 2.00)),((3.00 0.00,2.00 1.00,1.00 1.00,0.00 0.00)),((3.00 2.00,2.00 1.00,3.00 0.00)),((0.00 2.00,1.00 1.00,2.00 1.00,3.00 2.00)))",
                             "StraightSkeletonTest.cpp / testStraightSkeletonPartitionSimpleRectangle")

    let upstreamLShape = try UpstreamParity.geometry("POLYGON ((0 0,0 2,1 2,1 1,2 1,2 0,0 0))")
        .straightSkeletonPartition()
    #expect(upstreamLShape.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID)
    UpstreamParity.expectWKT(upstreamLShape, decimals: 2,
                             equals: "POLYHEDRALSURFACE (((0.00 0.00,0.50 0.50,0.50 1.50,0.00 2.00)),((2.00 0.00,1.50 0.50,0.50 0.50,0.00 0.00)),((2.00 1.00,1.50 0.50,2.00 0.00)),((1.00 1.00,0.50 0.50,1.50 0.50,2.00 1.00)),((1.00 2.00,0.50 1.50,0.50 0.50,1.00 1.00)),((0.00 2.00,0.50 1.50,1.00 2.00)))",
                             "StraightSkeletonTest.cpp / testStraightSkeletonPartitionLShapedPolygon")

    let upstreamWithHole = try UpstreamParity.geometry(
        "POLYGON ((0 0,0 4,4 4,4 0,0 0),(1 1,3 1,3 3,1 3,1 1))"
    ).straightSkeletonPartition()
    #expect(upstreamWithHole.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID)
    UpstreamParity.expectWKT(upstreamWithHole, decimals: 2,
                             equals: "POLYHEDRALSURFACE (((0.00 0.00,0.50 0.50,0.50 3.50,0.00 4.00)),((4.00 0.00,3.50 0.50,0.50 0.50,0.00 0.00)),((4.00 4.00,3.50 3.50,3.50 0.50,4.00 0.00)),((0.00 4.00,0.50 3.50,3.50 3.50,4.00 4.00)),((1.00 1.00,0.50 0.50,3.50 0.50,3.00 1.00)),((1.00 3.00,0.50 3.50,0.50 0.50,1.00 1.00)),((3.00 3.00,3.50 3.50,0.50 3.50,1.00 3.00)),((3.00 1.00,3.50 0.50,3.50 3.50,3.00 3.00)))",
                             "StraightSkeletonTest.cpp / testStraightSkeletonPartitionPolygonWithHole")

    let upstreamMultiPolygon = try UpstreamParity.geometry(
        "MULTIPOLYGON (((0 0,0 2,2 2,2 0,0 0)),((3 3,3 5,5 5,5 3,3 3)))"
    ).straightSkeletonPartition()
    #expect(upstreamMultiPolygon.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID)
    UpstreamParity.expectWKT(upstreamMultiPolygon, decimals: 2,
                             equals: "POLYHEDRALSURFACE (((0.00 0.00,1.00 1.00,0.00 2.00)),((2.00 0.00,1.00 1.00,0.00 0.00)),((2.00 2.00,1.00 1.00,2.00 0.00)),((0.00 2.00,1.00 1.00,2.00 2.00)),((3.00 3.00,4.00 4.00,3.00 5.00)),((5.00 3.00,4.00 4.00,3.00 3.00)),((5.00 5.00,4.00 4.00,5.00 3.00)),((3.00 5.00,4.00 4.00,5.00 5.00)))",
                             "StraightSkeletonTest.cpp / testStraightSkeletonPartitionMultiPolygon")

    let emptyPartition = try UpstreamParity.geometry("POLYGON EMPTY").straightSkeletonPartition()
    UpstreamParity.expectWKT(emptyPartition, decimals: 2,
                             equals: "POLYHEDRALSURFACE EMPTY",
                             "StraightSkeletonTest.cpp / testStraightSkeletonPartitionEmptyPolygon")

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
