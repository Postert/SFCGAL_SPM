import Foundation
import Testing
@testable import SwiftSFCGAL

@Test func upstreamUnionPointPointCases() throws {
    // Upstream: algorithm/UnionTest.cpp / Handle1, Handle2, PointPoint
    let same = try UpstreamParity.geometry("POINT (0 1)").union(UpstreamParity.geometry("POINT (0 1)"))
    #expect(same.geometryTypeID == UpstreamParity.pointTypeID)
    UpstreamParity.expectWKT(same, decimals: 0, equals: "POINT (0 1)", "UnionTest.cpp / PointPoint")

    let duplicateMultiPoint = try UpstreamParity.geometry("MULTIPOINT (0 1,0 1,0 1)").union(
        UpstreamParity.geometry("POINT (0 1)")
    )
    #expect(duplicateMultiPoint.geometryTypeID == UpstreamParity.pointTypeID)
    UpstreamParity.expectWKT(duplicateMultiPoint, decimals: 0, equals: "POINT (0 1)",
                             "UnionTest.cpp / Handle2")

    let different = try UpstreamParity.geometry("POINT (0 0)").union(UpstreamParity.geometry("POINT (0 1)"))
    #expect(different.geometryTypeID == UpstreamParity.multiPointTypeID)
    #expect(try different.covers(UpstreamParity.geometry("POINT (0 0)")))
    #expect(try different.covers(UpstreamParity.geometry("POINT (0 1)")))

    let same3D = try UpstreamParity.geometry("POINT (0 1 1)").union3D(UpstreamParity.geometry("POINT (0 1 1)"))
    #expect(same3D.geometryTypeID == UpstreamParity.pointTypeID)
    UpstreamParity.expectWKT(same3D, decimals: 0, equals: "POINT Z (0 1 1)", "UnionTest.cpp / PointPoint")

    let different3D = try UpstreamParity.geometry("POINT (0 0 0)").union3D(
        UpstreamParity.geometry("POINT (0 0 1)")
    )
    #expect(different3D.geometryTypeID == UpstreamParity.multiPointTypeID)
    UpstreamParity.expectAlmostEqual(try different3D.distance3D(to: UpstreamParity.geometry("POINT (0 0 0)")), 0.0,
                                     "UnionTest.cpp / PointPoint")
    UpstreamParity.expectAlmostEqual(try different3D.distance3D(to: UpstreamParity.geometry("POINT (0 0 1)")), 0.0,
                                     "UnionTest.cpp / PointPoint")
}

@Test func upstreamUnionLineAndPolygonCases() throws {
    // Upstream: algorithm/UnionTest.cpp / PointLine, LineLine, PolygonPolygon1,
    // PolygonPolygon2, PolygonPolygon3
    let pointLine = try UpstreamParity.geometry("POINT (.5 0)").union(
        UpstreamParity.geometry("LINESTRING (-1 0,1 0)")
    )
    #expect(pointLine.geometryTypeID == UpstreamParity.lineStringTypeID)
    UpstreamParity.expectWKT(pointLine, decimals: 1,
                             equals: "LINESTRING (-1.0 0.0,0.5 0.0,1.0 0.0)",
                             "UnionTest.cpp / PointLine")

    let pointLine3D = try UpstreamParity.geometry("POINT (0 0 0.5)").union3D(
        UpstreamParity.geometry("LINESTRING (0 0 -1,0 0 1)")
    )
    #expect(pointLine3D.geometryTypeID == UpstreamParity.lineStringTypeID)
    UpstreamParity.expectWKT(pointLine3D, decimals: 1,
                             equals: "LINESTRING Z (0.0 0.0 -1.0,0.0 0.0 0.5,0.0 0.0 1.0)",
                             "UnionTest.cpp / PointLine")

    let parallelLines = try UpstreamParity.geometry("LINESTRING (-1 0,1 0)").union(
        UpstreamParity.geometry("LINESTRING (-1 1,1 1)")
    )
    #expect(parallelLines.geometryTypeID == UpstreamParity.multiLineStringTypeID)
    UpstreamParity.expectWKT(parallelLines, decimals: 0,
                             equals: "MULTILINESTRING ((-1 0,1 0),(-1 1,1 1))",
                             "UnionTest.cpp / LineLine")

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

    let baseSquare = try UpstreamParity.geometry("POLYGON ((0 0,1 0,1 1,0 1,0 0))")
    let gridA = try GeometryCollection()
    let gridB = try GeometryCollection()
    for i in 0 ..< 4 {
        for j in 0 ..< 4 {
            let translated = try baseSquare.translated(dx: pow(Double(i), 1.3), dy: pow(Double(j), 1.3))
            try gridA.addGeometry(translated)
            try gridB.addGeometry(try translated.translated(dx: 0.5, dy: 0.5))
        }
    }

    let gridUnion = try gridA.union(gridB)
    UpstreamParity.expectAlmostEqual(try gridUnion.area(), 25.56, tolerance: 0.01,
                                     "UnionTest.cpp / PolygonPolygon3")
}

@Test func upstreamUnionSurfaceAndVolumeCases() throws {
    // Upstream: algorithm/UnionTest.cpp / LineVolume, PointSurface, PointVolume,
    // TriangleTriangle, VolumeVolume
    let cube = try UpstreamParity.geometry(UpstreamParity.upstreamCubeSolidWKT())

    let lineVolume = try UpstreamParity.geometry("LINESTRING (-1 -1 -1,2 2 2)").union3D(cube)
    let lineVolumeCollection = try #require(lineVolume as? GeometryCollection)
    #expect(lineVolumeCollection.numGeometries == 3)
    #expect(lineVolumeCollection.geometryAt(0).geometryTypeID == UpstreamParity.lineStringTypeID)
    #expect(lineVolumeCollection.geometryAt(1).geometryTypeID == UpstreamParity.lineStringTypeID)
    #expect(lineVolumeCollection.geometryAt(2).geometryTypeID == UpstreamParity.solidTypeID)

    let trianglePoint = try UpstreamParity.geometry("TRIANGLE ((0 0,0 1,1 0,0 0))").union(
        UpstreamParity.geometry("POINT (.1 .1)")
    )
    #expect(trianglePoint.geometryTypeID == UpstreamParity.triangleTypeID)
    UpstreamParity.expectAlmostEqual(try trianglePoint.area(), 0.5,
                                     "UnionTest.cpp / PointSurface")

    let trianglePoint3D = try UpstreamParity.geometry("TRIANGLE ((0 0 1,0 1 1,1 0 1,0 0 1))").union3D(
        UpstreamParity.geometry("POINT (.1 .1 1)")
    )
    #expect(trianglePoint3D.geometryTypeID == UpstreamParity.triangleTypeID)

    let pointInsideVolume = try cube.union3D(UpstreamParity.geometry("POINT (.1 .1 1)"))
    #expect(pointInsideVolume.geometryTypeID == UpstreamParity.solidTypeID)

    let pointOutsideVolume = try cube.union3D(UpstreamParity.geometry("POINT (-.1 .1 1)"))
    #expect(pointOutsideVolume.geometryTypeID == UpstreamParity.geometryCollectionTypeID)

    let triangleTriangle = try UpstreamParity.geometry("TRIANGLE ((0 0,1 0,0 1,0 0))").union(
        UpstreamParity.geometry("TRIANGLE ((0 0,1 0,0 1,0 0))")
    )
    #expect(triangleTriangle.geometryTypeID == UpstreamParity.triangleTypeID)
    UpstreamParity.expectAlmostEqual(try triangleTriangle.area(), 0.5,
                                     "UnionTest.cpp / TriangleTriangle")

    let disjointVolumes = try cube.union3D(cube.translated(dx: 2.0, dy: 0.0, dz: 0.0))
    #expect(disjointVolumes.geometryTypeID == UpstreamParity.multiSolidTypeID)
    UpstreamParity.expectAlmostEqual(try disjointVolumes.volume(), 2.0, tolerance: 1e-8,
                                     "UnionTest.cpp / VolumeVolume")

    let overlappingVolumes = try cube.union3D(cube.translated(dx: 0.5, dy: 0.0, dz: 0.0))
    #expect(overlappingVolumes.geometryTypeID == UpstreamParity.solidTypeID)
    UpstreamParity.expectAlmostEqual(try overlappingVolumes.volume(), 1.5, tolerance: 1e-8,
                                     "UnionTest.cpp / VolumeVolume")

    let faceTouchingVolumes = try cube.union3D(cube.translated(dx: 1.0, dy: 0.0, dz: 0.0))
    #expect(faceTouchingVolumes.geometryTypeID == UpstreamParity.solidTypeID)
    UpstreamParity.expectAlmostEqual(try faceTouchingVolumes.volume(), 2.0, tolerance: 1e-8,
                                     "UnionTest.cpp / VolumeVolume")

    let edgeTouchingVolumes = try cube.union3D(cube.translated(dx: 1.0, dy: 1.0, dz: 0.0))
    #expect(edgeTouchingVolumes.geometryTypeID == UpstreamParity.multiSolidTypeID)
    UpstreamParity.expectAlmostEqual(try edgeTouchingVolumes.volume(), 2.0, tolerance: 1e-8,
                                     "UnionTest.cpp / VolumeVolume")

    let cornerTouchingVolumes = try cube.union3D(cube.translated(dx: 1.0, dy: 1.0, dz: 1.0))
    #expect(cornerTouchingVolumes.geometryTypeID == UpstreamParity.multiSolidTypeID)
    UpstreamParity.expectAlmostEqual(try cornerTouchingVolumes.volume(), 2.0, tolerance: 1e-8,
                                     "UnionTest.cpp / VolumeVolume")
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

    let samePoint = try UpstreamParity.geometry("POINT (0 0)").difference(
        UpstreamParity.geometry("POINT (0 0)")
    )
    UpstreamParity.expectWKT(samePoint, decimals: 0, equals: "GEOMETRYCOLLECTION EMPTY",
                             "DifferenceTest.cpp / testDifferenceXPoint")

    let pointOnLine = try UpstreamParity.geometry("POINT (0 0)").difference(
        UpstreamParity.geometry("LINESTRING (0 0,1 1)")
    )
    UpstreamParity.expectWKT(pointOnLine, decimals: 0, equals: "GEOMETRYCOLLECTION EMPTY",
                             "DifferenceTest.cpp / testDifferenceXLineString")

    let pointOffLine = try UpstreamParity.geometry("POINT (0 0)").difference(
        UpstreamParity.geometry("LINESTRING (0 1,1 1)")
    )
    UpstreamParity.expectWKT(pointOffLine, decimals: 0, equals: "POINT (0 0)",
                             "DifferenceTest.cpp / testDifferenceXLineString")

    let splitLine = try UpstreamParity.geometry("LINESTRING (0 0,1 0)").difference(
        UpstreamParity.geometry("LINESTRING (0.5 0,0.7 0)")
    )
    #expect(splitLine.geometryTypeID == UpstreamParity.multiLineStringTypeID)
    UpstreamParity.expectWKT(splitLine, decimals: 1,
                             equals: "MULTILINESTRING ((0.0 0.0,0.5 0.0),(0.7 0.0,1.0 0.0))",
                             "DifferenceTest.cpp / testDifferenceXLineString")

    let splitLineReversed = try UpstreamParity.geometry("LINESTRING (0 0,1 0)").difference(
        UpstreamParity.geometry("LINESTRING (0.7 0,0.5 0)")
    )
    UpstreamParity.expectWKT(splitLineReversed, decimals: 1,
                             equals: "MULTILINESTRING ((0.0 0.0,0.5 0.0),(0.7 0.0,1.0 0.0))",
                             "DifferenceTest.cpp / testDifferenceXLineString")

    let crossingLine = try UpstreamParity.geometry("LINESTRING (-1 0,1 0)").difference(
        UpstreamParity.geometry("LINESTRING (0 -1,0 1)")
    )
    UpstreamParity.expectWKT(crossingLine, decimals: 0,
                             equals: "LINESTRING (-1 0,1 0)",
                             "DifferenceTest.cpp / testDifferenceXLineString")

    let partlyOverlappedLine = try UpstreamParity.geometry("LINESTRING (0 0,1 0)").difference(
        UpstreamParity.geometry("LINESTRING (-1 0,0.7 0)")
    )
    UpstreamParity.expectWKT(partlyOverlappedLine, decimals: 1,
                             equals: "LINESTRING (0.7 0.0,1.0 0.0)",
                             "DifferenceTest.cpp / testDifferenceXLineString")

    let coveredLine = try UpstreamParity.geometry("LINESTRING (0 0,1 0)").difference(
        UpstreamParity.geometry("LINESTRING (-1 0,2 0)")
    )
    UpstreamParity.expectWKT(coveredLine, decimals: 0,
                             equals: "GEOMETRYCOLLECTION EMPTY",
                             "DifferenceTest.cpp / testDifferenceXLineString")

    let disjointLine = try UpstreamParity.geometry("LINESTRING (0 0,1 0)").difference(
        UpstreamParity.geometry("LINESTRING (0 1,1 1)")
    )
    UpstreamParity.expectWKT(disjointLine, decimals: 0,
                             equals: "LINESTRING (0 0,1 0)",
                             "DifferenceTest.cpp / testDifferenceXLineString")

    let multiSegmentLine = try UpstreamParity.geometry("LINESTRING (0 0,1 0,1 1)").difference(
        UpstreamParity.geometry("LINESTRING (0.3 0,1 0,1 0.4)")
    )
    UpstreamParity.expectWKT(multiSegmentLine, decimals: 1,
                             equals: "MULTILINESTRING ((0.0 0.0,0.3 0.0),(1.0 0.4,1.0 1.0))",
                             "DifferenceTest.cpp / testDifferenceXLineString")

    let identicalPolygons = try UpstreamParity.geometry("POLYGON ((-1 -1,1 -1,1 1,-1 1,-1 -1))").difference(
        UpstreamParity.geometry("POLYGON ((-1 -1,1 -1,1 1,-1 1,-1 -1))")
    )
    UpstreamParity.expectWKT(identicalPolygons, decimals: 0,
                             equals: "GEOMETRYCOLLECTION EMPTY",
                             "DifferenceTest.cpp / testDifferencePolygonPolygon2D")

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

    let offPolygon = try UpstreamParity.geometry("POINT (0.5 0.5 0.6)").difference3D(
        UpstreamParity.geometry("POLYGON ((0 0 0,1 1 1,1 0 1,0 0 0))")
    )
    UpstreamParity.expectWKT(offPolygon, decimals: 1, equals: "POINT Z (0.5 0.5 0.6)",
                             "DifferenceTest.cpp / testDifferencePoinPolygon2D")

    let onPolygon = try UpstreamParity.geometry("POINT (0.5 0.5 0.5)").difference3D(
        UpstreamParity.geometry("POLYGON ((0 0 0,1 1 1,1 0 1,0 0 0))")
    )
    UpstreamParity.expectWKT(onPolygon, decimals: 0, equals: "GEOMETRYCOLLECTION EMPTY",
                             "DifferenceTest.cpp / testDifferencePoinPolygon2D")

    let solid = try UpstreamParity.geometry(UpstreamParity.upstreamCubeSolidWKT())
    let pointInside = try UpstreamParity.geometry("POINT (0.5 0.5 0.5)").difference3D(solid)
    UpstreamParity.expectWKT(pointInside, decimals: 0, equals: "GEOMETRYCOLLECTION EMPTY",
                             "DifferenceTest.cpp / testDifferencePoinVolume")

    let pointOutside = try UpstreamParity.geometry("POINT (1.001 0.5 0.5)").difference3D(solid)
    UpstreamParity.expectWKT(pointOutside, decimals: 3, equals: "POINT Z (1.001 0.500 0.500)",
                             "DifferenceTest.cpp / testDifferencePoinVolume")
}

@Test func upstreamDifference3DSurfaceAndVolumeCases() throws {
    // Upstream: algorithm/DifferenceTest.cpp / testDifferenceVolumeVolume,
    // testDifferenceLinePolygon, testDifferenceTriangleTriangle3D,
    // testDifferenceTriangleVolume, testDifferenceLineVolume, testDifferencePolygonVolume
    let cube = try UpstreamParity.geometry(UpstreamParity.upstreamCubeSolidWKT())

    let identicalVolumes = try cube.difference3D(UpstreamParity.geometry(UpstreamParity.upstreamCubeSolidWKT()))
    UpstreamParity.expectWKT(identicalVolumes, decimals: 0, equals: "GEOMETRYCOLLECTION EMPTY",
                             "DifferenceTest.cpp / testDifferenceVolumeVolume")

    let topHalf = try UpstreamParity.geometry(
        """
        SOLID (
          (
            ((0 0 0.5,0 1 0.5,1 1 0.5,1 0 0.5,0 0 0.5)),
            ((0 0 0.5,0 0 1,0 1 1,0 1 0.5,0 0 0.5)),
            ((0 0 0.5,1 0 0.5,1 0 1,0 0 1,0 0 0.5)),
            ((1 1 1,0 1 1,0 0 1,1 0 1,1 1 1)),
            ((1 1 1,1 0 1,1 0 0.5,1 1 0.5,1 1 1)),
            ((1 1 1,1 1 0.5,0 1 0.5,0 1 1,1 1 1))
          )
        )
        """
    )
    UpstreamParity.expectAlmostEqual(try cube.difference3D(topHalf).volume(), 0.5, tolerance: 1e-8,
                                     "DifferenceTest.cpp / testDifferenceVolumeVolume")

    let linePolygon = try UpstreamParity.geometry("LINESTRING (-10 0,10 0)").difference(
        UpstreamParity.geometry(
            "POLYGON ((-1 -1,1 -1,1 1,-1 1,-1 -1),(-0.5 -0.5,-0.5 0.5,0 0,-0.5 -0.5),(0.5 0.5,0.5 -0.5,0 0,0.5 0.5))"
        )
    )
    UpstreamParity.expectWKT(linePolygon, decimals: 1,
                             equals: "MULTILINESTRING ((-10.0 0.0,-1.0 0.0),(-0.5 0.0,0.0 0.0,0.5 0.0),(1.0 0.0,10.0 0.0))",
                             "DifferenceTest.cpp / testDifferenceLinePolygon")

    let triangle = try UpstreamParity.geometry("TRIANGLE ((0 0 0,0 1 1,1 0 0,0 0 0))")
    let nonCoplanarTriangle = try triangle.difference3D(
        UpstreamParity.geometry("TRIANGLE ((0 0 0,0 1 1.01,1 0 0,0 0 0))")
    )
    #expect(nonCoplanarTriangle.geometryTypeID == UpstreamParity.triangleTypeID)
    UpstreamParity.expectAlmostEqual(try nonCoplanarTriangle.area3D(), try triangle.area3D(),
                                     tolerance: 1e-8,
                                     "DifferenceTest.cpp / testDifferenceTriangleTriangle3D")

    let disjointTriangle = try triangle.difference3D(
        UpstreamParity.geometry("TRIANGLE ((.6 .6 .6,1.6 1.6 1.6,1.6 .6 .6,.6 .6 .6))")
    )
    #expect(disjointTriangle.geometryTypeID == UpstreamParity.triangleTypeID)
    UpstreamParity.expectAlmostEqual(try disjointTriangle.area3D(), try triangle.area3D(),
                                     tolerance: 1e-8,
                                     "DifferenceTest.cpp / testDifferenceTriangleTriangle3D")

    let splitTriangle = try triangle.difference3D(
        UpstreamParity.geometry("TRIANGLE ((.1 .1 .1,1.6 1.6 1.6,1.6 .6 .6,.1 .1 .1))")
    )
    #expect(splitTriangle.geometryTypeID == UpstreamParity.triangulatedSurfaceTypeID)
    #expect(try splitTriangle.area3D() > 0.0)
    #expect(try splitTriangle.area3D() < triangle.area3D())

    let triangleMinusVolume = try UpstreamParity.geometry(
        "TRIANGLE ((0 0 .5,10 0 .5,0 10 .5,0 0 .5))"
    ).difference3D(cube)
    #expect(triangleMinusVolume.geometryTypeID == UpstreamParity.triangulatedSurfaceTypeID)
    #expect(try triangleMinusVolume.area3D() > 0.0)

    let lineMinusVolume = try UpstreamParity.geometry(
        "LINESTRING (-3 -3 .5,3 3 .5,1 1.1 .5,1 .1 .5,.1 .1 .5)"
    ).difference3D(cube)
    #expect(lineMinusVolume.geometryTypeID == UpstreamParity.multiLineStringTypeID)
    #expect((lineMinusVolume as? MultiLineString)?.numGeometries == 2,
            "DifferenceTest.cpp / testDifferenceLineVolume")
    UpstreamParity.expectAlmostEqual(try lineMinusVolume.length3D(), 9.92969065669222,
                                     tolerance: 1e-8,
                                     "DifferenceTest.cpp / testDifferenceLineVolume")

    let polygonMinusVolume = try UpstreamParity.geometry(
        "POLYGON ((1 -1 -1,1 1 -1,1 1 1,1 -1 1,1 -1 -1))"
    ).difference3D(cube)
    #expect(!polygonMinusVolume.asWKT().isEmpty,
            "DifferenceTest.cpp / testDifferencePolygonVolume")
}
