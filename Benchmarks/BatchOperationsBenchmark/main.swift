import Foundation
import SwiftSFCGAL

private var benchmarkSink = 0

@inline(never)
private func consume(_ value: Int) {
    benchmarkSink &+= value
}

private func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    let middle = sorted.count / 2
    if sorted.count % 2 == 0 {
        return (sorted[middle - 1] + sorted[middle]) / 2.0
    }
    return sorted[middle]
}

private func measure(_ name: String,
                     iterations: Int = 10,
                     _ block: () throws -> Int) rethrows -> Double {
    for _ in 0..<3 {
        consume(try block())
    }

    var times: [Double] = []
    times.reserveCapacity(iterations)
    for _ in 0..<iterations {
        let start = Date()
        consume(try block())
        times.append(Date().timeIntervalSince(start) * 1000.0)
    }

    let result = median(times)
    print("\(name): \(String(format: "%.3f", result)) ms median")
    return result
}

private func speedupPercent(baseline: Double, candidate: Double) -> Double {
    guard baseline > 0 else { return 0 }
    return ((baseline - candidate) / baseline) * 100.0
}

private func makeCityGMLSurfaceWKTs(buildingCount: Int = 20) -> [String] {
    var surfaces: [String] = []
    surfaces.reserveCapacity(buildingCount * 6)

    for i in 0..<buildingCount {
        let col = i % 5
        let row = i / 5
        let x = Double(col) * 18.0
        let y = Double(row) * 16.0
        let width = 8.0 + Double(i % 3)
        let depth = 6.0 + Double(i % 4)
        let height = 9.0 + Double(i % 5)
        let roofRise = 2.0 + Double(i % 3) * 0.4
        let x2 = x + width
        let y2 = y + depth
        let midY = y + depth / 2.0

        surfaces.append("POLYGON((\(x) \(y),\(x2) \(y),\(x2) \(y2),\(x) \(y2),\(x) \(y)))")
        surfaces.append("POLYGON Z((\(x) \(y) 0,\(x2) \(y) 0,\(x2) \(y) \(height),\(x) \(y) \(height),\(x) \(y) 0))")
        surfaces.append("POLYGON Z((\(x2) \(y) 0,\(x2) \(y2) 0,\(x2) \(y2) \(height),\(x2) \(y) \(height),\(x2) \(y) 0))")
        surfaces.append("POLYGON Z((\(x2) \(y2) 0,\(x) \(y2) 0,\(x) \(y2) \(height),\(x2) \(y2) \(height),\(x2) \(y2) 0))")
        surfaces.append("POLYGON Z((\(x) \(y2) 0,\(x) \(y) 0,\(x) \(y) \(height),\(x) \(y2) \(height),\(x) \(y2) 0))")
        surfaces.append("POLYGON Z((\(x) \(y) \(height),\(x2) \(y) \(height),\(x2) \(midY) \(height + roofRise),\(x) \(midY) \(height + roofRise),\(x) \(y) \(height)))")
    }

    return surfaces
}

private func run() throws {
    initializeSFCGAL()

    let wkts = makeCityGMLSurfaceWKTs()
    let geometries = try wkts.map(Geometry.fromWKT)
    let vertexCapacity = wkts.count * 64

    print("Batch Operations Benchmark")
    print("Surfaces: \(wkts.count)")
    print("Iterations: 10 measured, 3 warmup")
    print("")

    let swiftLoop = try measure("Swift loop tesselate") {
        let results = try geometries.map { try $0.tesselate() }
        return results.count
    }

    let batchLoop = try measure("C batch tesselate") {
        let results = try batchTesselate(geometries)
        return results.count
    }

    let swiftPipeline = try measure("Swift WKT -> vertices pipeline") {
        var total = 0
        for wkt in wkts {
            total += try Geometry.fromWKT(wkt).triangleVertices().count
        }
        return total
    }

    let cPipeline = try measure("C WKT -> vertices pipeline") {
        let result = try batchWKTToVertices(wkts, vertexCapacity: vertexCapacity)
        return result.vertices.count
    }

    let tessSpeedup = speedupPercent(baseline: swiftLoop, candidate: batchLoop)
    let pipelineSpeedup = speedupPercent(baseline: swiftPipeline, candidate: cPipeline)

    print("")
    print("Batch tesselate speedup: \(String(format: "%.2f", tessSpeedup))%")
    print("WKT-to-vertices speedup: \(String(format: "%.2f", pipelineSpeedup))%")
    if tessSpeedup < 5.0 {
        print("Batch tesselate is below the 5% public API threshold on this run.")
    }
    if pipelineSpeedup < 5.0 {
        print("WKT-to-vertices is below the 5% threshold on this run.")
    }
    consume(benchmarkSink)
}

try run()
