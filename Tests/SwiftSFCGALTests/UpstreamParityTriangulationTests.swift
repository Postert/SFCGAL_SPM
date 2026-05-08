import Testing
@testable import SwiftSFCGAL

@Test func upstreamTesselateInvariantCases() throws {
    // Upstream: algorithm/TesselateTest.cpp / testPoint, testLineString,
    // testMultiPoint, testMultiLineString
    let cases: [(String, String)] = [
        ("POINT (3.0 4.0)", "POINT (3.0 4.0)"),
        ("LINESTRING (0.0 0.0,1.0 1.0)", "LINESTRING (0.0 0.0,1.0 1.0)"),
        ("MULTIPOINT ((3.0 4.0),(5.0 6.0))", "MULTIPOINT ((3.0 4.0),(5.0 6.0))"),
        (
            "MULTILINESTRING ((0.0 0.0,1.0 1.0),(1.0 1.0,2.0 2.0))",
            "MULTILINESTRING ((0.0 0.0,1.0 1.0),(1.0 1.0,2.0 2.0))"
        )
    ]

    for (input, expected) in cases {
        let result = try UpstreamParity.geometry(input).tesselate()
        UpstreamParity.expectWKT(result, decimals: 1, equals: expected,
                                 "TesselateTest.cpp / invariant cases")
    }
}

@Test func upstreamTesselatePolygonCase() throws {
    // Upstream: algorithm/TesselateTest.cpp / testPolygon
    let result = try UpstreamParity.geometry(
        "POLYGON ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0))"
    ).tesselate()
    #expect(result.geometryTypeID == UpstreamParity.triangulatedSurfaceTypeID)
    let tin = try #require(result as? TriangulatedSurface)
    #expect(tin.numPatches == 2)
    UpstreamParity.expectAlmostEqual(try result.area3D(), 1.0, tolerance: 1e-8)
}

@Test func upstreamTesselateMultiPolygonCase() throws {
    // Upstream: algorithm/TesselateTest.cpp / testMultiPolygon
    let result = try UpstreamParity.geometry(
        "MULTIPOLYGON (((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0)),((2.0 0.0,3.0 0.0,3.0 1.0,2.0 1.0,2.0 0.0)))"
    ).tesselate()
    #expect(result.geometryTypeID == UpstreamParity.geometryCollectionTypeID)
    let collection = try #require(result as? GeometryCollection)
    #expect(collection.numGeometries == 2)
    UpstreamParity.expectAlmostEqual(try result.area3D(), 2.0, tolerance: 1e-8)
}

@Test func upstreamTriangulate2DZCases() throws {
    // Upstream: triangulate/Triangulate2DZTest.cpp / testPoint, testLineString,
    // testPolygonWithHole, testMultiPoint, testMultiPolygon
    let point = try UpstreamParity.geometry("POINT (1.0 2.0 3.0)").triangulate2DZ()
    #expect(point.geometryTypeID == UpstreamParity.triangulatedSurfaceTypeID)
    #expect((point as? TriangulatedSurface)?.numPatches == 0)

    let line = try UpstreamParity.geometry("LINESTRING (0.0 0.0,1.0 0.0,1.0 1.0,2.0 1.0)").triangulate2DZ()
    #expect(line.geometryTypeID == UpstreamParity.triangulatedSurfaceTypeID)
    #expect((line as? TriangulatedSurface)?.numPatches == 2)

    let polygonWithHole = try UpstreamParity.geometry(
        "POLYGON ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0),(0.2 0.2,0.2 0.8,0.8 0.8,0.8 0.2,0.2 0.2))"
    ).triangulate2DZ()
    #expect(polygonWithHole.geometryTypeID == UpstreamParity.triangulatedSurfaceTypeID)
    #expect((polygonWithHole as? TriangulatedSurface)?.numPatches == 10)

    let multiPolygon = try UpstreamParity.geometry(
        "MULTIPOLYGON (((0 0,1 0,1 1,0 1,0 0)),((2 0,3 0,3 1,2 1,2 0)))"
    ).triangulate2DZ()
    #expect(multiPolygon.geometryTypeID == UpstreamParity.geometryCollectionTypeID ||
            multiPolygon.geometryTypeID == UpstreamParity.triangulatedSurfaceTypeID)
}

@Test func upstreamTriangleVerticesMatchTesselationArea() throws {
    // Upstream: algorithm/TesselateTest.cpp / testPolygon, adapted for Swift GPU vertex helper.
    let polygon = try UpstreamParity.geometry(
        "POLYGON ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0))"
    )
    let vertices = try polygon.triangleVertices()
    #expect(vertices.count == 18)
    UpstreamParity.expectAlmostEqual(try polygon.tesselate().area3D(), 1.0, tolerance: 1e-8)
}
