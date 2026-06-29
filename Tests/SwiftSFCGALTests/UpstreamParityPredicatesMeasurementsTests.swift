import Testing
@testable import SwiftSFCGAL

@Test func upstreamIsValidCases() throws {
    // Upstream: algorithm/IsValidTest.cpp / geometryIsValid, geometryWithNan, disconnectedTIN
    let valid = try UpstreamParity.geometry("POLYGON ((0 0,0 1,1 1,1 0,0 0))")
    #expect(valid.isValid)
    #expect(valid.validationResult().isValid)

    let invalid = try UpstreamParity.geometry("POLYGON ((0 0,1 1,1 0,0 1,0 0))")
    #expect(!invalid.isValid)
    #expect(!invalid.validationResult().isValid)

    let disconnectedTIN = try UpstreamParity.geometry(
        "TIN (((0 0,1 0,0 1,0 0)),((10 10,11 10,10 11,10 10)))"
    )
    #expect(!disconnectedTIN.validationResult().isValid)
}

@Test func upstreamCoversAndIntersectsInlineCases() throws {
    // Upstream: algorithm/CoversTest.cpp / testFileCoversTest,
    // algorithm/IntersectsTest.cpp / testFileIntersectsTest, adapted with inline WKT.
    let square = try UpstreamParity.geometry("POLYGON ((0 0,1 0,1 1,0 1,0 0))")
    let innerPoint = try UpstreamParity.geometry("POINT (0.5 0.5)")
    let boundaryPoint = try UpstreamParity.geometry("POINT (1 1)")
    let outsidePoint = try UpstreamParity.geometry("POINT (2 2)")
    let overlapping = try UpstreamParity.geometry("POLYGON ((0.5 0,1.5 0,1.5 1,0.5 1,0.5 0))")
    let separate = try UpstreamParity.geometry("POLYGON ((2 0,3 0,3 1,2 1,2 0))")

    #expect(try square.covers(innerPoint))
    #expect(try square.covers(boundaryPoint))
    #expect(try !square.covers(outsidePoint))
    #expect(try square.intersects(overlapping))
    #expect(try !square.intersects(separate))
}

@Test func upstreamDistanceCases() throws {
    // Upstream: algorithm/DistanceTest.cpp / selected point, line, polygon, multipoint cases
    let p00 = try Point(x: 0.0, y: 0.0)
    let p34 = try Point(x: 3.0, y: 4.0)
    UpstreamParity.expectAlmostEqual(try p00.distance(to: p00), 0.0,
                                     "DistanceTest.cpp / testDistancePointPoint")
    UpstreamParity.expectAlmostEqual(try p00.distance(to: p34), 5.0,
                                     "DistanceTest.cpp / testDistancePointPoint")

    let p111 = try Point(x: 1.0, y: 1.0, z: 1.0)
    let p415 = try Point(x: 4.0, y: 1.0, z: 5.0)
    UpstreamParity.expectAlmostEqual(try p111.distance3D(to: p415), 5.0,
                                     "DistanceTest.cpp / testDistancePointPoint3D")

    let pointOnLine = try UpstreamParity.geometry("POINT (1.0 1.0)")
    let diagonal = try UpstreamParity.geometry("LINESTRING (0.0 0.0,2.0 2.0)")
    UpstreamParity.expectAlmostEqual(try pointOnLine.distance(to: diagonal), 0.0,
                                     "DistanceTest.cpp / testDistancePointLineString_pointOnLineString")

    let pointOffLine = try UpstreamParity.geometry("POINT (0.0 1.0)")
    UpstreamParity.expectAlmostEqual(try pointOffLine.distance(to: diagonal),
                                     2.0.squareRoot() / 2.0,
                                     "DistanceTest.cpp / testDistancePointLineString_pointOutOfLineString")

    let pointInsidePolygon = try UpstreamParity.geometry("POINT (0.5 0.5)")
    let unitSquare = try UpstreamParity.geometry("POLYGON ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0))")
    UpstreamParity.expectAlmostEqual(try pointInsidePolygon.distance(to: unitSquare), 0.0,
                                     "DistanceTest.cpp / testDistancePointPolygon_pointInPolygon")

    let disjointA = try UpstreamParity.geometry("POLYGON ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0))")
    let disjointB = try UpstreamParity.geometry("POLYGON ((2.0 0.0,3.0 0.0,3.0 1.0,2.0 1.0,2.0 0.0))")
    UpstreamParity.expectAlmostEqual(try disjointA.distance(to: disjointB), 1.0,
                                     "DistanceTest.cpp / testDistancePolygonPolygon_disjoint")

    let multipointA = try UpstreamParity.geometry("MULTIPOINT ((0.0 0.0),(1.0 0.0),(1.0 1.0),(0.0 1.0))")
    let multipointB = try UpstreamParity.geometry("MULTIPOINT ((8.0 8.0),(4.0 5.0))")
    UpstreamParity.expectAlmostEqual(try multipointA.distance(to: multipointB), 5.0,
                                     "DistanceTest.cpp / testDistanceMultiPointMultiPoint_disjoint")
}

@Test func upstreamDistanceEmptyAnd3DEdgeCases() throws {
    // Upstream: algorithm/DistanceTest.cpp / empty point, collapsed/zero-length segments,
    // line-triangle, triangle-triangle, and polygon-solid cases.
    let emptyPointDistance = try UpstreamParity.point("POINT EMPTY").distance(to: UpstreamParity.point("POINT EMPTY"))
    #expect(emptyPointDistance.isInfinite,
            "DistanceTest.cpp / testDistanceBetweenEmptyPointsIsInfinity")

    let collapsed3DPoint = try UpstreamParity.geometry("POINT (0.0 3.0 4.0)")
    let collapsed3DLine = try UpstreamParity.geometry("LINESTRING (0.0 0.0 0.0,0.0 -1.0 -1.0)")
    UpstreamParity.expectAlmostEqual(try collapsed3DPoint.distance3D(to: collapsed3DLine), 5.0,
                                     "DistanceTest.cpp / testDistancePointLineString3D_pointOnLineString_collapsedSegments")

    let zeroLengthLineA = try UpstreamParity.geometry("LINESTRING (0.0 0.0,-1.0 -1.0)")
    let zeroLengthLineB = try UpstreamParity.geometry("LINESTRING (3.0 4.0,4.0 5.0)")
    UpstreamParity.expectAlmostEqual(try zeroLengthLineA.distance(to: zeroLengthLineB), 5.0,
                                     "DistanceTest.cpp / testDistanceLineStringLineString_zeroLengthSegments")

    let zeroLengthLine3DA = try UpstreamParity.geometry("LINESTRING (0.0 0.0 0.0,-1.0 -1.0 -1.0)")
    let zeroLengthLine3DB = try UpstreamParity.geometry("LINESTRING (0.0 3.0 4.0,0.0 4.0 5.0)")
    UpstreamParity.expectAlmostEqual(try zeroLengthLine3DA.distance3D(to: zeroLengthLine3DB), 5.0,
                                     "DistanceTest.cpp / testDistanceLineStringLineString3D_zeroLengthSegments")

    let containingTriangle = try UpstreamParity.geometry(
        "TRIANGLE ((-4.0 0.0 1.0,4.0 0.0 1.0,0.0 4.0 1.0,-4.0 0.0 1.0))"
    )
    let lineInTriangle = try UpstreamParity.geometry("LINESTRING (-1.0 0.0 1.0,1.0 0.0 1.0)")
    UpstreamParity.expectAlmostEqual(try lineInTriangle.distance3D(to: containingTriangle), 0.0,
                                     "DistanceTest.cpp / testDistance3DLineStringTriangle_lineStringInTriangle")

    let lineNearestAtStart = try UpstreamParity.geometry("LINESTRING (-1.0 0.0 2.0,1.0 0.0 3.0)")
    UpstreamParity.expectAlmostEqual(try lineNearestAtStart.distance3D(to: containingTriangle), 1.0,
                                     "DistanceTest.cpp / testDistance3DLineStringTriangle_lineStringStartPointIsNearest")

    let containedTriangle = try UpstreamParity.geometry(
        "TRIANGLE ((-3.0 0.0 1.0,3.0 0.0 1.0,0.0 3.0 1.0,-3.0 0.0 1.0))"
    )
    UpstreamParity.expectAlmostEqual(try containedTriangle.distance3D(to: containingTriangle), 0.0,
                                     "DistanceTest.cpp / testDistance3DTriangleTriangle_contained")

    let parallelTriangle = try UpstreamParity.geometry(
        "TRIANGLE ((-4.0 0.0 2.0,4.0 0.0 2.0,0.0 4.0 2.0,-4.0 0.0 2.0))"
    )
    UpstreamParity.expectAlmostEqual(try containedTriangle.distance3D(to: parallelTriangle), 1.0,
                                     "DistanceTest.cpp / testDistance3DTriangleTriangle_parallel")

    let solid = try UpstreamParity.geometry(UpstreamParity.upstreamCubeSolidWKT())
    let intersectingPolygon = try UpstreamParity.geometry(
        "POLYGON Z ((1 -1 -1,1 1 -1,1 1 1,1 -1 1,1 -1 -1))"
    )
    UpstreamParity.expectAlmostEqual(try intersectingPolygon.distance3D(to: solid), 0.0,
                                     "DistanceTest.cpp / testDistancePolygonSolid")

    let disjointPolygon = try UpstreamParity.geometry(
        "POLYGON Z ((2 2 2,3 2 2,3 3 2,2 3 2,2 2 2))"
    )
    UpstreamParity.expectAlmostEqual(try disjointPolygon.distance3D(to: solid), 1.7320508,
                                     tolerance: 1e-6,
                                     "DistanceTest.cpp / testDistancePolygonSolid_disjoint")
}

@Test func upstreamLengthCases() throws {
    // Upstream: algorithm/LengthTest.cpp / testZeroLength, testZeroLengthVertical,
    // testLengthLineString, test3DLengthVertical, test3DLengthLineString, testLength_invalidType
    UpstreamParity.expectAlmostEqual(try UpstreamParity.geometry("POINT (0.0 0.0)").length(), 0.0)
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("POLYGON ((0 0,0 1,1 1,1 0,0 0))").length(), 0.0
    )
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("LINESTRING (0.0 0.0 0.0,0.0 0.0 1.0)").length(), 0.0
    )
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("LINESTRING (0.0 0.0,3.0 4.0)").length(), 5.0
    )
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("LINESTRING (0.0 0.0,0.0 1.0,1.0 1.0)").length(), 2.0
    )
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("LINESTRING (0.0 0.0 0.0,0.0 0.0 1.0)").length3D(), 1.0
    )
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("LINESTRING (0.0 0.0 0.0,0.0 1.0 0.0,0.0 1.0 1.0)").length3D(), 2.0
    )
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("TRIANGLE ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 0.0))").length(), 0.0
    )
}

@Test func upstreamAreaCases() throws {
    // Upstream: algorithm/AreaTest.cpp / testPoint2D3D, testLineString2D3D,
    // testArea2D_PolygonWithHoleWithBadOrientation, testArea3D_Triangle1/2,
    // testArea2D_Triangle, testArea3D_Square1x1, testArea3D_Square4X4, testArea3D_Square4X4WithHole
    for wkt in [
        "POINT EMPTY",
        "LINESTRING EMPTY",
        "POLYGON EMPTY",
        "MULTIPOINT EMPTY",
        "MULTILINESTRING EMPTY",
        "MULTIPOLYGON EMPTY",
        "GEOMETRYCOLLECTION EMPTY",
        "TIN EMPTY",
        "POLYHEDRALSURFACE EMPTY",
        "SOLID EMPTY",
        "MULTISOLID EMPTY"
    ] {
        let empty = try UpstreamParity.geometry(wkt)
        UpstreamParity.expectAlmostEqual(try empty.area(), 0.0,
                                         "AreaTest.cpp / testEmpty2D3D")
        UpstreamParity.expectAlmostEqual(try empty.area3D(), 0.0,
                                         "AreaTest.cpp / testEmpty2D3D")
    }

    UpstreamParity.expectAlmostEqual(try Point(x: 3.0, y: 4.0).area(), 0.0)
    UpstreamParity.expectAlmostEqual(try Point(x: 3.0, y: 4.0, z: 5.0).area3D(), 0.0)
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("LINESTRING (0.0 0.0,1.0 1.0)").area(), 0.0
    )
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("LINESTRING (0.0 0.0 0.0,1.0 1.0 1.0)").area3D(), 0.0
    )
    #expect(throws: SFCGALError.self) {
        // The upstream C++ test constructs the polygon directly with holes in the
        // same orientation as the shell. Through the current public Swift WKT path,
        // SFCGAL rejects that invalid 3D polygon before area calculation.
        _ = try UpstreamParity.geometry(
            "POLYGON ((0 0,5 0,5 5,0 5,0 0),(1 1,2 1,2 2,1 2,1 1),(3 3,4 3,4 4,3 4,3 3))"
        ).area3D()
    }
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("POLYGON ((0 0,5 0,5 5,0 5,0 0),(1 1,1 2,2 2,2 1,1 1),(3 3,3 4,4 4,4 3,3 3))").area3D(),
        23.0
    )
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("TRIANGLE ((0.0 0.0 0.0,0.0 0.0 1.0,0.0 1.0 0.0,0.0 0.0 0.0))").area3D(),
        0.5
    )
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("TRIANGLE ((0.0 0.0 0.0,0.0 0.0 4.0,0.0 4.0 0.0,0.0 0.0 0.0))").area3D(),
        8.0
    )
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("TRIANGLE ((0.0 0.0,4.0 0.0,4.0 4.0,0.0 0.0))").area(),
        8.0
    )
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("POLYGON ((0.0 0.0 0.0,0.0 0.0 1.0,0.0 1.0 1.0,0.0 1.0 0.0,0.0 0.0 0.0))").area3D(),
        1.0
    )
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("POLYGON ((0.0 0.0 0.0,0.0 0.0 4.0,0.0 4.0 4.0,0.0 4.0 0.0,0.0 0.0 0.0))").area3D(),
        16.0
    )
    UpstreamParity.expectAlmostEqual(
        try UpstreamParity.geometry("POLYGON ((0.0 0.0 0.0,0.0 0.0 4.0,0.0 4.0 4.0,0.0 4.0 0.0,0.0 0.0 0.0),(0.0 2.0 2.0,0.0 3.0 2.0,0.0 3.0 3.0,0.0 2.0 3.0,0.0 2.0 2.0))").area3D(),
        15.0
    )
}

@Test func upstreamVolumeCases() throws {
    // Upstream: algorithm/VolumeTest.cpp / cubeVolume, cubeWithHoleVolume,
    // invertedCubeVolume, polyhedronVolume
    let cube = try UpstreamParity.geometry(UpstreamParity.upstreamCubeSolidWKT())
    UpstreamParity.expectAlmostEqual(try cube.volume(), 1.0, tolerance: 1e-8)

    let invertedCube = try UpstreamParity.geometry(
        """
        SOLID ((((0 0 0,0 1 0,0 1 1,0 0 1,0 0 0)),
                 ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0)),
                 ((0 0 0,0 0 1,1 0 1,1 0 0,0 0 0)),
                 ((1 0 0,1 0 1,1 1 1,1 1 0,1 0 0)),
                 ((0 0 1,0 1 1,1 1 1,1 0 1,0 0 1)),
                 ((0 1 0,1 1 0,1 1 1,0 1 1,0 1 0))))
        """
    )
    UpstreamParity.expectAlmostEqual(try invertedCube.volume(), -1.0, tolerance: 1e-8)

    let tetraShell = try #require(UpstreamParity.geometry(
        "POLYHEDRALSURFACE Z (((0 0 0,0 1 0,1 0 0,0 0 0)),((0 0 0,1 0 0,0 0 1,0 0 0)),((0 0 0,0 0 1,0 1 0,0 0 0)),((1 0 0,0 1 0,0 0 1,1 0 0)))"
    ) as? PolyhedralSurface)
    let solid = try Solid(exteriorShell: tetraShell)
    UpstreamParity.expectAlmostEqual(try solid.volume() * 6.0, 1.0, tolerance: 1e-8)
}
