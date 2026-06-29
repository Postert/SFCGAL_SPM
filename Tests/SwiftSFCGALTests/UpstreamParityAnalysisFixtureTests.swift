import Foundation
import Testing
@testable import SwiftSFCGAL

#if !os(Windows)
@Test func upstreamAlphaShapes2DMultiPointFixtureCases() throws {
    // Upstream: algorithm/AlphaShapesTest.cpp / testAlphaShapes2D_MultiPoint
    let inputs = try upstreamDataLines("AlphaShapesWkt.txt")
    let expectedAlpha = try upstreamDataLines("AlphaShapesWkt_expected.txt")
    let expectedOptimal = try upstreamDataLines("AlphaShapesWkt_expected_optimal.txt")
    let expectedOptimalHoles = try upstreamDataLines("AlphaShapesWkt_expected_optimal_holes.txt")

    #expect(inputs.count == expectedAlpha.count)
    #expect(inputs.count == expectedOptimal.count)
    #expect(inputs.count == expectedOptimalHoles.count)

    for index in inputs.indices {
        let geometry = try UpstreamParity.geometry(inputs[index])
        UpstreamParity.expectWKT(try geometry.alphaShapes(alpha: 1000.0), decimals: 1,
                                 equals: expectedAlpha[index],
                                 "AlphaShapesTest.cpp / testAlphaShapes2D_MultiPoint alpha")
        UpstreamParity.expectWKT(try geometry.optimalAlphaShapes(), decimals: 1,
                                 equals: expectedOptimal[index],
                                 "AlphaShapesTest.cpp / testAlphaShapes2D_MultiPoint optimal")
        UpstreamParity.expectWKT(try geometry.optimalAlphaShapes(allowHoles: true), decimals: 1,
                                 equals: expectedOptimalHoles[index],
                                 "AlphaShapesTest.cpp / testAlphaShapes2D_MultiPoint optimal holes")
    }
}
#endif

@Test func upstreamAlphaWrapping3DMultiPointFixtureCase() throws {
    // Upstream: algorithm/AlphaWrapping3DTest.cpp / testAlphaWrapping3D_MultiPoint
    let bunny = try UpstreamParity.geometry(upstreamDataText("bunny1000Wkt.txt"))
    let wrapped = try #require(bunny.alphaWrapping3D(relativeAlpha: 20) as? PolyhedralSurface)
    #expect(wrapped.numPatches >= 2304)
}

private func upstreamDataLines(_ name: String) throws -> [String] {
    try upstreamDataText(name)
        .split(whereSeparator: \.isNewline)
        .map(String.init)
}

private func upstreamDataText(_ name: String) throws -> String {
    let candidateURL = Bundle.module.url(forResource: name, withExtension: nil)
        ?? Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "UpstreamData")
    let url = try #require(candidateURL)
    return try String(contentsOf: url, encoding: .utf8)
}
