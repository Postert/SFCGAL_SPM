import Testing
@testable import SwiftSFCGAL
import CSFCGAL_Shim

@Test func testBatchTesselateExPerGeometryErrors() throws {
    TestSupport.initializeSFCGALOnce()

    let square = try TestGeometry.fromWKT(GeometryFixtures.Polygons2D.unitSquare)
    let triangle = try TestGeometry.fromWKT(GeometryFixtures.Polygons2D.unitTriangle)

    let inputs: [UnsafeRawPointer?] = [
        UnsafeRawPointer(square.handle),
        nil,
        UnsafeRawPointer(triangle.handle),
    ]
    var outputs = Array<UnsafeMutableRawPointer?>(repeating: nil, count: inputs.count)
    var errors = Array<UnsafePointer<CChar>?>(repeating: nil, count: inputs.count)

    let successCount = inputs.withUnsafeBufferPointer { inputBuffer in
        outputs.withUnsafeMutableBufferPointer { outputBuffer in
            errors.withUnsafeMutableBufferPointer { errorBuffer in
                sfcgal_swift_batch_tesselate_ex(
                    inputBuffer.baseAddress,
                    inputs.count,
                    outputBuffer.baseAddress,
                    errorBuffer.baseAddress)
            }
        }
    }
    defer {
        for output in outputs {
            if let output {
                sfcgal_geometry_delete(output)
            }
        }
    }

    #expect(Int(successCount) == 2)
    #expect(outputs[0] != nil)
    #expect(outputs[1] == nil)
    #expect(outputs[2] != nil)
    #expect(errors[0] == nil)
    #expect(errors[1] != nil)
    #expect(errors[2] == nil)
    #expect(String(cString: errors[1]!).contains("NULL"))
    #expect(sfcgal_swift_has_error() == 1)
}

@Test func testBatchTesselateSwiftAPI() throws {
    TestSupport.initializeSFCGALOnce()

    let square = try TestGeometry.fromWKT(GeometryFixtures.Polygons2D.unitSquare)
    let wall = try TestGeometry.fromWKT(GeometryFixtures.Polygons3D.verticalWall)

    let results = try batchTesselateForTesting([square, wall])

    #expect(results.count == 2)
    #expect(results[0] is TriangulatedSurface)
    #expect(results[1] is TriangulatedSurface)
    #expect(results[0].isValid)
    #expect(results[1].isValid)
}

@Test func testBatchTesselateSwiftAPIEmptyInput() throws {
    TestSupport.initializeSFCGALOnce()

    let results = try batchTesselateForTesting([])

    #expect(results.isEmpty)
}

@Test func testBatchTesselateMatchesSwiftLoop() throws {
    TestSupport.initializeSFCGALOnce()

    let geometries = try [
        GeometryFixtures.Polygons2D.unitSquare,
        GeometryFixtures.Polygons2D.unitTriangle,
        GeometryFixtures.PolygonsWithHoles.squareWithCenteredHole,
        GeometryFixtures.Polygons3D.verticalWall,
        GeometryFixtures.CityGML.wallSurface,
        GeometryFixtures.CityGML.slopedRoofSurface,
    ].map(TestGeometry.fromWKT)

    let swiftResults = try geometries.map { try $0.tesselate() }
    let batchResults = try batchTesselateForTesting(geometries)

    #expect(batchResults.count == swiftResults.count)
    for index in swiftResults.indices {
        #expect(batchResults[index].geometryType == swiftResults[index].geometryType)
        #expect(batchResults[index].asWKB() == swiftResults[index].asWKB())
    }
}

@Test func testBatchWktToVertices() throws {
    TestSupport.initializeSFCGALOnce()

    let wkts = [
        "POLYGON((0 0,1 0,0 1,0 0))",
        "POLYGON((2 0,3 0,2 1,2 0))",
        "POLYGON Z((0 0 1,1 0 1,0 1 2,0 0 1))",
    ]

    let result = try batchWKTToVertices(wkts, vertexCapacity: 64)

    #expect(result.vertexCounts == [3, 3, 3])
    #expect(result.vertices.count == 27)
    #expect(vertexTripleSet(result.vertices) == Set([
        "0,0,0",
        "1000,0,0",
        "0,1000,0",
        "2000,0,0",
        "3000,0,0",
        "2000,1000,0",
        "0,0,1000",
        "1000,0,1000",
        "0,1000,2000",
    ]))
}

@Test func testBatchWktToVerticesMatchesSwiftPipeline() throws {
    TestSupport.initializeSFCGALOnce()

    let wkts = [
        GeometryFixtures.Polygons2D.unitSquare,
        GeometryFixtures.PolygonsWithHoles.squareWithCenteredHole,
        GeometryFixtures.Polygons3D.verticalWall,
        GeometryFixtures.CityGML.wallSurface,
        GeometryFixtures.CityGML.slopedRoofSurface,
    ]

    let swiftVertices = try wkts.flatMap {
        try TestGeometry.fromWKT($0).triangleVertices()
    }
    let result = try batchWKTToVertices(wkts, vertexCapacity: swiftVertices.count)

    #expect(result.vertexCounts.reduce(0, +) * 3 == result.vertices.count)
    #expect(result.vertices.count == swiftVertices.count)
    #expect(result.vertices.elementsEqual(swiftVertices, by: { TestSupport.almostEqual($0, $1) }))
}

@Test func testBatchWktToVerticesInvalidWKTThrows() {
    TestSupport.initializeSFCGALOnce()

    #expect(throws: SFCGALError.self) {
        _ = try batchWKTToVertices([
            "POLYGON((0 0,1 0,0 1,0 0))",
            "NOT VALID WKT",
        ], vertexCapacity: 64)
    }
}

@Test func testBatchWktToVerticesInsufficientCapacityThrows() {
    TestSupport.initializeSFCGALOnce()

    #expect(throws: SFCGALError.self) {
        _ = try batchWKTToVertices([
            "POLYGON((0 0,1 0,0 1,0 0))",
        ], vertexCapacity: 8)
    }
}

private func vertexTripleSet(_ vertices: [Float]) -> Set<String> {
    var triples = Set<String>()
    for i in stride(from: 0, to: vertices.count, by: 3) {
        let x = Int((vertices[i] * 1000).rounded())
        let y = Int((vertices[i + 1] * 1000).rounded())
        let z = Int((vertices[i + 2] * 1000).rounded())
        triples.insert("\(x),\(y),\(z)")
    }
    return triples
}
