import Testing
@testable import SwiftSFCGAL

@Test func upstreamTesselateEmptyCases() throws {
    // Upstream: algorithm/TesselateTest.cpp / testEmpty
    let cases = [
        ("POINT EMPTY", "POINT EMPTY"),
        ("LINESTRING EMPTY", "LINESTRING EMPTY"),
        ("POLYGON EMPTY", "TIN EMPTY"),
        ("MULTIPOINT EMPTY", "MULTIPOINT EMPTY"),
        ("MULTILINESTRING EMPTY", "MULTILINESTRING EMPTY"),
        ("MULTIPOLYGON EMPTY", "GEOMETRYCOLLECTION EMPTY"),
        ("GEOMETRYCOLLECTION EMPTY", "GEOMETRYCOLLECTION EMPTY"),
        ("POLYHEDRALSURFACE EMPTY", "TIN EMPTY"),
        ("TIN EMPTY", "TIN EMPTY"),
        ("TRIANGLE EMPTY", "TRIANGLE EMPTY"),
        ("SOLID EMPTY", "GEOMETRYCOLLECTION EMPTY"),
        ("MULTISOLID EMPTY", "GEOMETRYCOLLECTION EMPTY")
    ]

    for (input, expected) in cases {
        let result = try UpstreamParity.geometry(input).tesselate()
        UpstreamParity.expectEmptyWKT(result,
                                      equals: expected,
                                      "TesselateTest.cpp / testEmpty")
    }
}

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
    UpstreamParity.expectWKT(result, decimals: 1,
                             equals: "TIN (((0.0 1.0,1.0 0.0,1.0 1.0,0.0 1.0)),((0.0 1.0,0.0 0.0,1.0 0.0,0.0 1.0)))",
                             "TesselateTest.cpp / testPolygon")
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
    UpstreamParity.expectWKT(result, decimals: 1,
                             equals: "GEOMETRYCOLLECTION (TIN (((0.0 1.0,1.0 0.0,1.0 1.0,0.0 1.0)),((0.0 1.0,0.0 0.0,1.0 0.0,0.0 1.0))),TIN (((2.0 1.0,3.0 0.0,3.0 1.0,2.0 1.0)),((2.0 1.0,2.0 0.0,3.0 0.0,2.0 1.0))))",
                             "TesselateTest.cpp / testMultiPolygon")
    #expect(result.geometryTypeID == UpstreamParity.geometryCollectionTypeID)
    let collection = try #require(result as? GeometryCollection)
    #expect(collection.numGeometries == 2)
    UpstreamParity.expectAlmostEqual(try result.area3D(), 2.0, tolerance: 1e-8)
}

@Test func upstreamTriangulate2DZCases() throws {
    // Upstream: triangulate/Triangulate2DZTest.cpp / testPoint, testLineString,
    // testPolygonWithHole, testMultiPoint, testMultiPolygon, testSolid
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

    let multiPoint = try UpstreamParity.geometry(
        "MULTIPOINT ((1.0 2.0 3.0),(2.0 3.0 6.0),(8.0 6.0 7.0),(2.0 1.0 6.0))"
    ).triangulate2DZ()
    #expect(multiPoint.geometryTypeID == UpstreamParity.triangulatedSurfaceTypeID)
    #expect((multiPoint as? TriangulatedSurface)?.numPatches == 2)

    let multiPolygon = try UpstreamParity.geometry(upstreamTriangulate2DZMultiPolygonWKT).triangulate2DZ()
    #expect(multiPolygon.geometryTypeID == UpstreamParity.triangulatedSurfaceTypeID)
    #expect((multiPolygon as? TriangulatedSurface)?.numPatches == 72)

    #expect(throws: SFCGALError.self) {
        _ = try UpstreamParity.geometry(upstreamTriangulate2DZSolidWKT).triangulate2DZ()
    }
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

private let upstreamTriangulate2DZMultiPolygonWKT = [
    "GEOMETRYCOLLECTION (LINESTRING (-1.52451708766716 ",
    "0.583952451708767,-1.5408618127786 0.361069836552749,-1.47251114413076 ",
    "0.317979197622586,-1.30163447251114 0.398216939078752,-1.32095096582467 ",
    "0.482912332838039,-1.08320950965825 ",
    "0.598811292719168,-0.809806835066865 ",
    "0.570579494799406,-0.517087667161962 ",
    "0.662704309063893),POLYGON ((-1.46508172362556 ",
    "0.615156017830609,-1.35215453194651 0.806835066864785,-1.08320950965825 ",
    "0.754829123328381,-1.10401188707281 0.630014858841011,-1.2407132243685 ",
    "0.557206537890045,-1.46508172362556 ",
    "0.615156017830609)),POLYGON ((-1.2778603268945 ",
    "0.316493313521545,-0.925705794947994 ",
    "0.540861812778603,-0.557206537890045 0.37444279346211,-1.09806835066865 ",
    "0.0267459138187223,-1.2927191679049 0.197622585438336,-1.2778603268945 ",
    "0.316493313521545),(-0.922734026745914 ",
    "0.448736998514116,-1.03566121842496 0.393759286775632,-1.0297176820208 ",
    "0.329866270430907,-0.87369985141159 ",
    "0.286775631500743,-0.739970282317979 ",
    "0.332838038632987,-0.922734026745914 ",
    "0.448736998514116),(-1.12778603268945 ",
    "0.295690936106984,-1.21545319465082 0.280832095096583,-1.23476968796434 ",
    "0.225854383358098,-1.14858841010401 0.184249628528975,-1.0520059435364 ",
    "0.210995542347697,-1.12778603268945 ",
    "0.295690936106984)),POINT (-1.22288261515602 ",
    "0.438335809806835),POINT (-1.1887072808321 ",
    "0.24962852897474),POINT (-1.09658246656761 ",
    "0.526002971768202),POINT (-0.967310549777118 ",
    "0.225854383358098),POINT (-0.936106983655275 ",
    "0.472511144130758),POINT (-0.882615156017831 ",
    "0.335809806835067),POINT (-0.821693907875186 ",
    "0.607726597325409),POINT (-0.708766716196137 ",
    "0.243684992570579),POINT (-0.643387815750372 ",
    "0.471025260029718),POINT (-0.632986627043091 ",
    "0.674591381872214),POINT (-0.476968796433878 ",
    "0.242199108469539),POINT (-0.456166419019317 ",
    "0.573551263001486),POINT (-0.349182763744428 0.386329866270431))"
].joined()

private let upstreamTriangulate2DZSolidWKT = """
SOLID ((((0 0 0, 0 1 0, 1 1 0, 1 0 0, 0 0 0)),
        ((0 0 0, 0 0 1, 0 1 1, 0 1 0, 0 0 0)),
        ((0 0 0, 1 0 0, 1 0 1, 0 0 1, 0 0 0)),
        ((1 1 1, 0 1 1, 0 0 1, 1 0 1, 1 1 1)),
        ((1 1 1, 1 0 1, 1 0 0, 1 1 0, 1 1 1)),
        ((1 1 1, 1 1 0, 0 1 0, 0 1 1, 1 1 1))))
"""
