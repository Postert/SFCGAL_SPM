import Testing
@testable import SwiftSFCGAL

@Test func testCoreGeometryFixturesParse() throws {
    let wkts = [
        GeometryFixtures.Polygons2D.unitSquare,
        GeometryFixtures.Polygons2D.unitTriangle,
        GeometryFixtures.Polygons2D.lShape,
        GeometryFixtures.PolygonsWithHoles.squareWithCenteredHole,
        GeometryFixtures.Polygons3D.flatUnitSquare,
        GeometryFixtures.Polygons3D.verticalWall,
        GeometryFixtures.Polygons3D.nonPlanarQuad,
        GeometryFixtures.MultiGeometries.unitSquareCorners,
        GeometryFixtures.MultiGeometries.twoLineStrings,
        GeometryFixtures.MultiGeometries.twoUnitSquares,
        GeometryFixtures.MultiGeometries.collectionPointAndLine,
        GeometryFixtures.Degenerate.zeroAreaPolygon,
        GeometryFixtures.Degenerate.collinearPoints,
        GeometryFixtures.Degenerate.bowtiePolygon,
        GeometryFixtures.Degenerate.emptyPolygon,
        GeometryFixtures.CityGML.buildingFootprint,
        GeometryFixtures.CityGML.wallSurface,
        GeometryFixtures.CityGML.sideWallSurface,
        GeometryFixtures.CityGML.flatRoofSurface,
        GeometryFixtures.CityGML.gabledRoofSurface,
        GeometryFixtures.CityGML.slopedRoofSurface,
        GeometryFixtures.Lines.line345,
        GeometryFixtures.Lines.diagonal3D,
        GeometryFixtures.Points.origin2D,
        GeometryFixtures.Points.point123,
        GeometryFixtures.Surfaces.twoPatchPolyhedralSurface,
        GeometryFixtures.Surfaces.twoTriangleTIN,
        GeometryFixtures.Solids.unitCube
    ]

    for wkt in wkts {
        let geometry = try TestGeometry.fromWKT(wkt)
        #expect(!geometry.geometryType.isEmpty)
    }
}

@Test func testFixtureTypesAreAsExpected() throws {
    let square = try TestGeometry.unitSquare()
    let lShape = try TestGeometry.lShape()
    let squareWithHole = try TestGeometry.squareWithHole()
    let multipoint = try TestGeometry.fromWKT(GeometryFixtures.MultiGeometries.unitSquareCorners)
    let multilinestring = try TestGeometry.fromWKT(GeometryFixtures.MultiGeometries.twoLineStrings)
    let multipolygon = try TestGeometry.fromWKT(GeometryFixtures.MultiGeometries.twoUnitSquares)
    let polyhedral = try TestGeometry.fromWKT(GeometryFixtures.Surfaces.twoPatchPolyhedralSurface)
    let tin = try TestGeometry.fromWKT(GeometryFixtures.Surfaces.twoTriangleTIN)
    let solid = try TestGeometry.unitCube()

    #expect(square is Polygon)
    #expect(lShape is Polygon)
    #expect(squareWithHole is Polygon)
    #expect(multipoint is MultiPoint)
    #expect(multilinestring is MultiLineString)
    #expect(multipolygon is MultiPolygon)
    #expect(polyhedral is PolyhedralSurface)
    #expect(tin is TriangulatedSurface)
    #expect(solid is Solid)
}

@Test func testFixtureMeasurementsAreStable() throws {
    #expect(TestSupport.almostEqual(try TestGeometry.unitSquare().area(), 1.0))
    #expect(TestSupport.almostEqual(try TestGeometry.lShape().area(), 12.0))
    #expect(TestSupport.almostEqual(try TestGeometry.squareWithHole().area(), 12.0))
    #expect(TestSupport.almostEqual(try TestGeometry.unitCube().volume(), 1.0))
}

@Test func testCityGMLFixturesRepresent3DSurfaces() throws {
    let wall = try TestGeometry.fromWKT(GeometryFixtures.CityGML.wallSurface)
    let sideWall = try TestGeometry.fromWKT(GeometryFixtures.CityGML.sideWallSurface)
    let flatRoof = try TestGeometry.fromWKT(GeometryFixtures.CityGML.flatRoofSurface)
    let slopedRoof = try TestGeometry.fromWKT(GeometryFixtures.CityGML.slopedRoofSurface)

    #expect(wall is Polygon)
    #expect(sideWall is Polygon)
    #expect(flatRoof is Polygon)
    #expect(slopedRoof is Polygon)
    #expect(wall.asWKT().contains(" Z "))
    #expect(sideWall.asWKT().contains(" Z "))
    #expect(flatRoof.asWKT().contains(" Z "))
    #expect(slopedRoof.asWKT().contains(" Z "))
    #expect(try wall.area3D() > 0.0)
    #expect(try slopedRoof.area3D() > 0.0)
}

@Test func testDegenerateFixturesCoverInvalidAndEmptyCases() throws {
    let bowtie = try TestGeometry.fromWKT(GeometryFixtures.Degenerate.bowtiePolygon)
    let empty = try TestGeometry.fromWKT(GeometryFixtures.Degenerate.emptyPolygon)
    let collinear = try TestGeometry.fromWKT(GeometryFixtures.Degenerate.collinearPoints)

    #expect(!bowtie.validationResult().isValid)
    #expect(empty.geometryType == "Polygon")
    #expect(collinear is MultiPoint)
}
