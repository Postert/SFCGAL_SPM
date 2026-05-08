import Testing
@testable import SwiftSFCGAL

@Test func upstreamUnionPointPointCases() throws {
    // Upstream: algorithm/UnionTest.cpp / Handle1, Handle2, PointPoint
    let same = try UpstreamParity.geometry("POINT (0 1)").union(UpstreamParity.geometry("POINT (0 1)"))
    #expect(same.geometryTypeID == UpstreamParity.pointTypeID)
    UpstreamParity.expectWKT(same, decimals: 0, equals: "POINT (0 1)", "UnionTest.cpp / PointPoint")

    let different = try UpstreamParity.geometry("POINT (0 0)").union(UpstreamParity.geometry("POINT (0 1)"))
    #expect(different.geometryTypeID == UpstreamParity.multiPointTypeID)
    #expect(try different.covers(UpstreamParity.geometry("POINT (0 0)")))
    #expect(try different.covers(UpstreamParity.geometry("POINT (0 1)")))

    let same3D = try UpstreamParity.geometry("POINT (0 1 1)").union3D(UpstreamParity.geometry("POINT (0 1 1)"))
    #expect(same3D.geometryTypeID == UpstreamParity.pointTypeID)
    UpstreamParity.expectWKT(same3D, decimals: 0, equals: "POINT Z (0 1 1)", "UnionTest.cpp / PointPoint")
}

@Test func upstreamUnionLineAndPolygonCases() throws {
    // Upstream: algorithm/UnionTest.cpp / PointLine, LineLine, PolygonPolygon1, PolygonPolygon2
    let pointLine = try UpstreamParity.geometry("POINT (.5 0)").union(
        UpstreamParity.geometry("LINESTRING (-1 0,1 0)")
    )
    #expect(pointLine.geometryTypeID == UpstreamParity.lineStringTypeID)
    UpstreamParity.expectWKT(pointLine, decimals: 1,
                             equals: "LINESTRING (-1.0 0.0,0.5 0.0,1.0 0.0)",
                             "UnionTest.cpp / PointLine")

    let crossingLines = try UpstreamParity.geometry("LINESTRING (-1 0,1 0)").union(
        UpstreamParity.geometry("LINESTRING (0 -1,0 1)")
    )
    #expect(crossingLines.geometryTypeID == UpstreamParity.multiLineStringTypeID)

    let adjacentSquares = try UpstreamParity.geometry("POLYGON ((0 0,1 0,1 1,0 1,0 0))").union(
        UpstreamParity.geometry("POLYGON ((1 0,2 0,2 1,1 1,1 0))")
    )
    #expect(adjacentSquares.geometryTypeID == UpstreamParity.polygonTypeID)
    UpstreamParity.expectAlmostEqual(try adjacentSquares.area(), 2.0, tolerance: 1e-8)

    let overlapped = try UpstreamParity.geometry("POLYGON ((0 0,1 0,1 1,0 1,0 0))")
        .translated(dx: 0.75, dy: 0.0)
        .union(UpstreamParity.geometry(
            "GEOMETRYCOLLECTION (POLYGON ((0 0,1 0,1 1,0 1,0 0)),POLYGON ((1.5 0,2.5 0,2.5 1,1.5 1,1.5 0)))"
        ))
    UpstreamParity.expectAlmostEqual(try overlapped.area3D(), 2.5, tolerance: 1e-8)
}

@Test func upstreamIntersectionInlineCases() throws {
    // Upstream: algorithm/IntersectionTest.cpp / testFileIntersectionTest, adapted with stable inline WKT.
    let overlap = try UpstreamParity.geometry("POLYGON ((0 0,2 0,2 2,0 2,0 0))").intersection(
        UpstreamParity.geometry("POLYGON ((1 1,3 1,3 3,1 3,1 1))")
    )
    #expect(overlap.geometryTypeID == UpstreamParity.polygonTypeID)
    UpstreamParity.expectAlmostEqual(try overlap.area(), 1.0, tolerance: 1e-8)

    let pointIntersection = try UpstreamParity.geometry("LINESTRING (-1 0,1 0)").intersection(
        UpstreamParity.geometry("LINESTRING (0 -1,0 1)")
    )
    #expect(pointIntersection.geometryTypeID == UpstreamParity.pointTypeID)
    UpstreamParity.expectWKT(pointIntersection, decimals: 0, equals: "POINT (0 0)",
                             "IntersectionTest.cpp / inline crossing lines")
}

@Test func upstreamDifferencePointLineAndPolygonCases() throws {
    // Upstream: algorithm/DifferenceTest.cpp / testDifferenceXPoint,
    // testDifferenceXLineString, testDifferencePolygonPolygon2D
    let differentPoint = try UpstreamParity.geometry("POINT (1 0)").difference(
        UpstreamParity.geometry("POINT (0 0)")
    )
    #expect(differentPoint.geometryTypeID == UpstreamParity.pointTypeID)
    UpstreamParity.expectWKT(differentPoint, decimals: 0, equals: "POINT (1 0)",
                             "DifferenceTest.cpp / testDifferenceXPoint")

    let splitLine = try UpstreamParity.geometry("LINESTRING (0 0,1 0)").difference(
        UpstreamParity.geometry("LINESTRING (0.5 0,0.7 0)")
    )
    #expect(splitLine.geometryTypeID == UpstreamParity.multiLineStringTypeID)
    UpstreamParity.expectWKT(splitLine, decimals: 1,
                             equals: "MULTILINESTRING ((0.0 0.0,0.5 0.0),(0.7 0.0,1.0 0.0))",
                             "DifferenceTest.cpp / testDifferenceXLineString")

    let polygonHole = try UpstreamParity.geometry("POLYGON ((-1 -1,1 -1,1 1,-1 1,-1 -1))").difference(
        UpstreamParity.geometry("POLYGON ((-0.5 -0.5,1 -0.5,0.5 0.5,-0.5 0.5,-0.5 -0.5))")
    )
    #expect(polygonHole.isValid)
    UpstreamParity.expectAlmostEqual(try polygonHole.area(), 2.75, tolerance: 1e-8)
}

@Test func upstreamDifference3DPointLinePolygonVolumeCases() throws {
    // Upstream: algorithm/DifferenceTest.cpp / testDifferencePoinLine,
    // testDifferencePoinPolygon2D, testDifferencePoinVolume
    let offLine = try UpstreamParity.geometry("POINT (0.5 0.5 0.6)").difference3D(
        UpstreamParity.geometry("LINESTRING (0 0 0,1 1 1)")
    )
    #expect(offLine.geometryTypeID == UpstreamParity.pointTypeID)

    let onLine = try UpstreamParity.geometry("POINT (0.5 0.5 0.5)").difference3D(
        UpstreamParity.geometry("LINESTRING (0 0 0,1 1 1)")
    )
    #expect(onLine.geometryType == "GeometryCollection")
    UpstreamParity.expectWKT(onLine, decimals: 0, equals: "GEOMETRYCOLLECTION EMPTY",
                             "DifferenceTest.cpp / testDifferencePoinLine")

    let solid = try UpstreamParity.geometry(UpstreamParity.squareShellWKT())
    let pointInside = try UpstreamParity.geometry("POINT (0.5 0.5 0.5)").difference3D(solid)
    UpstreamParity.expectWKT(pointInside, decimals: 0, equals: "GEOMETRYCOLLECTION EMPTY",
                             "DifferenceTest.cpp / testDifferencePoinVolume")
}
