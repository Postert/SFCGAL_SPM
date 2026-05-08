import Foundation

/// Shared WKT fixtures for SwiftSFCGAL tests.
///
/// Keep these fixtures small, readable, and deterministic. They are intended
/// to cover common geometry categories and edge cases that recur across wrapper
/// tests without forcing every test file to invent its own WKT strings.
enum GeometryFixtures {

    enum Polygons2D {
        static let unitSquare = "POLYGON((0 0,1 0,1 1,0 1,0 0))"
        static let unitTriangle = "POLYGON((0 0,1 0,0 1,0 0))"
        static let rightTriangle3x4 = "POLYGON((0 0,3 0,0 4,0 0))"
        static let rectangle4x3 = "POLYGON((0 0,4 0,4 3,0 3,0 0))"
        static let longRectangle = "POLYGON((0 0,10 0,10 1,0 1,0 0))"
        static let lShape = "POLYGON((0 0,4 0,4 2,2 2,2 4,0 4,0 0))"
        static let shiftedUnitSquare = "POLYGON((2 0,3 0,3 1,2 1,2 0))"
        static let overlappingUnitSquare = "POLYGON((0.5 0,1.5 0,1.5 1,0.5 1,0.5 0))"
        static let innerUnitSquare = "POLYGON((0.25 0.25,0.75 0.25,0.75 0.75,0.25 0.75,0.25 0.25))"
        static let clockwiseUnitSquare = "POLYGON((0 0,0 1,1 1,1 0,0 0))"
    }

    enum PolygonsWithHoles {
        static let squareWithCenteredHole = "POLYGON((0 0,4 0,4 4,0 4,0 0),(1 1,1 3,3 3,3 1,1 1))"
        static let largeSquareWithHole = "POLYGON((0 0,10 0,10 10,0 10,0 0),(2 2,2 8,8 8,8 2,2 2))"
    }

    enum Polygons3D {
        static let flatUnitSquare = "POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))"
        static let shiftedFlatUnitSquare = "POLYGON Z ((0.5 0 0,1.5 0 0,1.5 1 0,0.5 1 0,0.5 0 0))"
        static let highFlatUnitSquare = "POLYGON Z ((0 0 5,1 0 5,1 1 5,0 1 5,0 0 5))"
        static let verticalWall = "POLYGON Z ((0 0 0,1 0 0,1 0 3,0 0 3,0 0 0))"
        static let verticalWallWide = "POLYGON Z ((0 0 0,4 0 0,4 0 3,0 0 3,0 0 0))"
        static let zSlopedSquare = "POLYGON Z ((0 0 0,1 0 0,1 1 10,0 1 10,0 0 0))"
        static let nonPlanarQuad = "POLYGON Z ((0 0 0,1 0 0,1 1 1,0 1 0,0 0 0))"
        static let rightTriangle3x4 = "POLYGON Z ((0 0 0,3 0 0,0 4 0,0 0 0))"
    }

    enum MultiGeometries {
        static let unitSquareCorners = "MULTIPOINT((0 0),(1 0),(1 1),(0 1))"
        static let unitSquareCornersWithCenter = "MULTIPOINT(0 0,1 0,1 1,0 1,0.5 0.5)"
        static let cubeCorners = "MULTIPOINT(0 0 0,1 0 0,1 1 0,0 1 0,0 0 1,1 0 1,1 1 1,0 1 1)"
        static let twoLineStrings = "MULTILINESTRING((0 0,1 1),(2 2,3 3))"
        static let twoUnitSquares = "MULTIPOLYGON(((0 0,1 0,1 1,0 1,0 0)),((2 2,3 2,3 3,2 3,2 2)))"
        static let collectionPointAndLine = "GEOMETRYCOLLECTION(POINT(1 2),LINESTRING(0 0,1 1))"
    }

    enum Degenerate {
        static let zeroAreaPolygon = "POLYGON((0 0,1 0,2 0,0 0))"
        static let collinearPoints = "MULTIPOINT((0 0),(1 0),(2 0),(3 0))"
        static let repeatedPointPolygon = "POLYGON((1 2,1 2,1 2,1 2))"
        static let bowtiePolygon = "POLYGON((0 0,1 1,1 0,0 1,0 0))"
        static let emptyPolygon = "POLYGON EMPTY"
    }

    enum CityGML {
        static let buildingFootprint = "POLYGON((0 0,12 0,12 8,8 8,8 12,0 12,0 0))"
        static let rectangularFootprint = "POLYGON((0 0,12 0,12 8,0 8,0 0))"
        static let wallSurface = "POLYGON Z ((0 0 0,12 0 0,12 0 4,0 0 4,0 0 0))"
        static let sideWallSurface = "POLYGON Z ((12 0 0,12 8 0,12 8 4,12 0 4,12 0 0))"
        static let flatRoofSurface = "POLYGON Z ((0 0 4,12 0 4,12 8 4,0 8 4,0 0 4))"
        static let gabledRoofSurface = "POLYGON Z ((0 0 4,12 0 4,6 4 7,0 0 4))"
        static let slopedRoofSurface = "POLYGON Z ((0 0 4,12 0 4,12 8 6,0 8 6,0 0 4))"
    }

    enum Lines {
        static let unitSegment = "LINESTRING(0 0,1 0)"
        static let line345 = "LINESTRING(0 0,3 4)"
        static let multiSegment = "LINESTRING(0 0,1 0,2 0,3 0)"
        static let diagonal3D = "LINESTRING Z (0 0 0,1 1 1)"
        static let flat3453D = "LINESTRING Z (0 0 0,3 4 0)"
    }

    enum Points {
        static let origin2D = "POINT(0 0)"
        static let point123 = "POINT(1 2 3)"
        static let pointInsideUnitSquare = "POINT(0.5 0.5)"
        static let pointOnUnitSquareCorner = "POINT(1 1)"
    }

    enum Surfaces {
        static let twoPatchPolyhedralSurface = """
        POLYHEDRALSURFACE Z (
          ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0)),
          ((0 0 0,0 0 1,1 0 1,1 0 0,0 0 0))
        )
        """

        static let twoTriangleTIN = "TIN Z (((0 0 0,1 0 0,0 1 0,0 0 0)),((1 0 0,1 1 0,0 1 0,1 0 0)))"
    }

    enum Solids {
        static let unitCube = """
        SOLID Z (
          (
            ((0 0 0,0 1 0,1 1 0,1 0 0,0 0 0)),
            ((0 0 1,1 0 1,1 1 1,0 1 1,0 0 1)),
            ((0 0 0,1 0 0,1 0 1,0 0 1,0 0 0)),
            ((1 0 0,1 1 0,1 1 1,1 0 1,1 0 0)),
            ((0 1 0,0 1 1,1 1 1,1 1 0,0 1 0)),
            ((0 0 0,0 0 1,0 1 1,0 1 0,0 0 0))
          )
        )
        """
    }
}

