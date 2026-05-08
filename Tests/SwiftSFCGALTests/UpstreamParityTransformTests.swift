import Foundation
import Testing
@testable import SwiftSFCGAL

@Test func upstreamTranslateCases() throws {
    // Upstream: transform/TranslateTest.cpp / testTranslatePoint2D,
    // testTranslatePoint3D, testTranslateLineString2D, testTranslatePolygon3D
    let point2D = try #require(Point(x: 1.0, y: 2.0).translated(dx: 3.0, dy: 4.0) as? Point)
    #expect(point2D.x == 4.0)
    #expect(point2D.y == 6.0)
    #expect(!point2D.is3D)

    let point3D = try #require(Point(x: 1.0, y: 2.0, z: 3.0).translated(dx: 4.0, dy: 5.0, dz: 6.0) as? Point)
    #expect(point3D.x == 5.0)
    #expect(point3D.y == 7.0)
    #expect(point3D.z == 9.0)

    let line = try UpstreamParity.geometry("LINESTRING (0 0,1 1)").translated(dx: 2.0, dy: 3.0)
    UpstreamParity.expectWKT(line, decimals: 0, equals: "LINESTRING (2 3,3 4)",
                             "TranslateTest.cpp / testTranslateLineString2D")

    let polygon = try UpstreamParity.geometry("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 0 0))")
        .translated(dx: 1.0, dy: 2.0, dz: 3.0)
    UpstreamParity.expectWKT(polygon, decimals: 0,
                             equals: "POLYGON Z ((1 2 3,2 2 3,2 3 3,1 2 3))",
                             "TranslateTest.cpp / testTranslatePolygon3D")
}

@Test func upstreamRotate2DAndAroundPointCases() throws {
    // Upstream: transform/RotateTest.cpp / testRotate2DOrigin, testRotate2DPoint,
    // capi/sfcgal_cTest.cpp / testRotate2D, testRotate2DAroundPoint
    let rotated = try #require(Point(x: 1.0, y: 0.0).rotated(angle: .pi / 2.0) as? Point)
    UpstreamParity.expectAlmostEqual(rotated.x, 0.0, tolerance: 1e-8)
    UpstreamParity.expectAlmostEqual(rotated.y, 1.0, tolerance: 1e-8)

    let around = try #require(Point(x: 2.0, y: 1.0).rotated2D(angle: .pi / 2.0, cx: 1.0, cy: 1.0) as? Point)
    UpstreamParity.expectAlmostEqual(around.x, 1.0, tolerance: 1e-8)
    UpstreamParity.expectAlmostEqual(around.y, 2.0, tolerance: 1e-8)
}

@Test func upstreamRotate3DAxisCases() throws {
    // Upstream: transform/RotateTest.cpp / testRotate3DZ, testRotateX, testRotateY, testRotateZ,
    // capi/sfcgal_cTest.cpp / testRotate3D, testRotate3DAroundCenter, testRotateX
    let aroundZ = try #require(Point(x: 1.0, y: 0.0, z: 0.0).rotated3D(angle: .pi / 2.0, ax: 0.0, ay: 0.0, az: 1.0) as? Point)
    UpstreamParity.expectAlmostEqual(aroundZ.x, 0.0, tolerance: 1e-8)
    UpstreamParity.expectAlmostEqual(aroundZ.y, 1.0, tolerance: 1e-8)
    UpstreamParity.expectAlmostEqual(aroundZ.z, 0.0, tolerance: 1e-8)

    let aroundX = try #require(Point(x: 0.0, y: 1.0, z: 0.0).rotatedX(angle: .pi / 2.0) as? Point)
    UpstreamParity.expectAlmostEqual(aroundX.x, 0.0, tolerance: 1e-8)
    UpstreamParity.expectAlmostEqual(aroundX.y, 0.0, tolerance: 1e-8)
    UpstreamParity.expectAlmostEqual(aroundX.z, 1.0, tolerance: 1e-8)

    let aroundY = try #require(Point(x: 0.0, y: 0.0, z: 1.0).rotatedY(angle: .pi / 2.0) as? Point)
    UpstreamParity.expectAlmostEqual(aroundY.x, 1.0, tolerance: 1e-8)
    UpstreamParity.expectAlmostEqual(aroundY.y, 0.0, tolerance: 1e-8)
    UpstreamParity.expectAlmostEqual(aroundY.z, 0.0, tolerance: 1e-8)

    let aroundCenter = try #require(Point(x: 2.0, y: 1.0, z: 0.0).rotated3D(
        angle: .pi / 2.0,
        ax: 0.0, ay: 0.0, az: 1.0,
        cx: 1.0, cy: 1.0, cz: 0.0
    ) as? Point)
    UpstreamParity.expectAlmostEqual(aroundCenter.x, 1.0, tolerance: 1e-8)
    UpstreamParity.expectAlmostEqual(aroundCenter.y, 2.0, tolerance: 1e-8)
}

@Test func upstreamScaleCases() throws {
    // Upstream: transform/ScaleTest.cpp / uniform, non-uniform, around-center cases,
    // capi/sfcgal_cTest.cpp / testScaleUniformC, testScaleNonUniformC, testScaleAroundCenterC
    let uniform = try #require(Point(x: 1.0, y: 2.0, z: 3.0).scaled(factor: 2.0) as? Point)
    #expect(uniform.x == 2.0)
    #expect(uniform.y == 4.0)
    #expect(uniform.z == 6.0)

    let nonUniform = try #require(Point(x: 1.0, y: 2.0, z: 3.0).scaled(sx: 2.0, sy: 3.0, sz: 4.0) as? Point)
    #expect(nonUniform.x == 2.0)
    #expect(nonUniform.y == 6.0)
    #expect(nonUniform.z == 12.0)

    let aroundCenter = try #require(Point(x: 2.0, y: 2.0, z: 2.0).scaled(
        sx: 2.0, sy: 2.0, sz: 2.0,
        cx: 1.0, cy: 1.0, cz: 1.0
    ) as? Point)
    #expect(aroundCenter.x == 3.0)
    #expect(aroundCenter.y == 3.0)
    #expect(aroundCenter.z == 3.0)

    let square = try UpstreamParity.geometry("POLYGON ((0 0,1 0,1 1,0 1,0 0))")
    UpstreamParity.expectAlmostEqual(try square.scaled(factor: 2.0).area(), 4.0,
                                     tolerance: 1e-8)
}

@Test func upstreamScaleCubeNonUniformCase() throws {
    // Upstream: capi/sfcgal_cTest.cpp / testScaleCubeNonUniformC
    let cube = try UpstreamParity.geometry(UpstreamParity.squareShellWKT())
    let scaled = try cube.scaled(sx: 2.0, sy: 3.0, sz: 4.0)
    UpstreamParity.expectAlmostEqual(try scaled.volume(), 24.0, tolerance: 1e-8)
}
