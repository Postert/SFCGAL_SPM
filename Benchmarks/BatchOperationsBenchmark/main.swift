import Foundation
import SwiftSFCGAL

#if canImport(FoundationXML)
    import FoundationXML
#endif

private var benchmarkSink = 0

private struct Coordinate: Equatable {
    let x: Double
    let y: Double
    let z: Double
}

private struct BenchmarkDataset {
    let name: String
    let source: String
    let wkts: [String]
    let isRealCityGML: Bool
}

private struct BenchmarkOptions {
    let inputPath: String?
    let maxSurfaces: Int?
}

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

private func measure(
    _ name: String,
    iterations: Int = 10,
    _ block: () throws -> Int
) rethrows -> Double {
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

private final class CityGMLSurfaceExtractor: NSObject, XMLParserDelegate {
    private static let buildingSurfaceNames: Set<String> = [
        "WallSurface",
        "RoofSurface",
        "GroundSurface",
        "ClosureSurface",
        "OuterCeilingSurface",
        "OuterFloorSurface",
        "CeilingSurface",
        "FloorSurface",
    ]

    private let maxSurfaces: Int?
    private var surfaceDepth = 0
    private var exteriorDepth = 0
    private var linearRingDepth = 0
    private var ringDimension = 3
    private var activeTextElement: String?
    private var activeText = ""
    private var activeTextDimension = 3
    private var currentRing: [Coordinate] = []
    private var didReachLimit = false

    private(set) var wkts: [String] = []

    init(maxSurfaces: Int?) {
        self.maxSurfaces = maxSurfaces
    }

    static func extractWKTs(from path: String, maxSurfaces: Int?) throws -> [String] {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let extractor = CityGMLSurfaceExtractor(maxSurfaces: maxSurfaces)
        let parser = XMLParser(data: data)
        parser.delegate = extractor
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false

        let success = parser.parse()
        if !success && !extractor.didReachLimit {
            throw parser.parserError
                ?? SFCGALError.parseError("Failed to parse CityGML file: \(path)")
        }
        return extractor.wkts
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = localName(elementName)

        if Self.buildingSurfaceNames.contains(name) {
            surfaceDepth += 1
        }

        if surfaceDepth > 0 && name == "exterior" {
            exteriorDepth += 1
        }

        if surfaceDepth > 0 && exteriorDepth > 0 && name == "LinearRing" {
            linearRingDepth += 1
            if linearRingDepth == 1 {
                currentRing.removeAll(keepingCapacity: true)
                ringDimension = dimension(from: attributeDict, defaultValue: 3)
            }
        }

        guard linearRingDepth > 0 else { return }

        if name == "pos" || name == "posList" {
            activeTextElement = name
            activeText = ""
            activeTextDimension = dimension(from: attributeDict, defaultValue: ringDimension)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if activeTextElement != nil {
            activeText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = localName(elementName)

        if let activeTextElement, activeTextElement == name {
            appendCoordinates(
                from: activeText,
                dimension: activeTextDimension,
                elementName: activeTextElement)
            self.activeTextElement = nil
            activeText = ""
        }

        if name == "LinearRing" && linearRingDepth > 0 {
            if linearRingDepth == 1,
                exteriorDepth > 0,
                surfaceDepth > 0,
                let wkt = polygonWKT(from: currentRing)
            {
                wkts.append(wkt)
                if let maxSurfaces, wkts.count >= maxSurfaces {
                    didReachLimit = true
                    parser.abortParsing()
                }
            }
            currentRing.removeAll(keepingCapacity: true)
            linearRingDepth -= 1
        }

        if surfaceDepth > 0 && name == "exterior" {
            exteriorDepth -= 1
        }

        if surfaceDepth > 0 && Self.buildingSurfaceNames.contains(name) {
            surfaceDepth -= 1
        }
    }

    private func appendCoordinates(
        from text: String,
        dimension: Int,
        elementName: String
    ) {
        let values =
            text
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap { Double($0) }

        if elementName == "pos" {
            guard values.count >= 2 else { return }
            currentRing.append(
                Coordinate(
                    x: values[0],
                    y: values[1],
                    z: values.count >= 3 ? values[2] : 0.0))
            return
        }

        let strideBy = max(2, dimension)
        guard values.count >= strideBy else { return }
        var index = 0
        while index + 1 < values.count {
            currentRing.append(
                Coordinate(
                    x: values[index],
                    y: values[index + 1],
                    z: strideBy >= 3 && index + 2 < values.count ? values[index + 2] : 0.0))
            index += strideBy
        }
    }
}

private func localName(_ name: String) -> String {
    if let colon = name.lastIndex(of: ":") {
        return String(name[name.index(after: colon)...])
    }
    return name
}

private func dimension(
    from attributes: [String: String],
    defaultValue: Int
) -> Int {
    for key in ["srsDimension", "dimension", "gml:srsDimension"] {
        if let value = attributes[key], let dimension = Int(value), dimension >= 2 {
            return dimension
        }
    }
    return defaultValue
}

private func polygonWKT(from ring: [Coordinate]) -> String? {
    guard ring.count >= 3 else { return nil }
    var closedRing = ring
    if closedRing.first != closedRing.last, let first = closedRing.first {
        closedRing.append(first)
    }
    guard closedRing.count >= 4 else { return nil }

    let coordinates =
        closedRing
        .map { "\(formatNumber($0.x)) \(formatNumber($0.y)) \(formatNumber($0.z))" }
        .joined(separator: ",")
    return "POLYGON Z((\(coordinates)))"
}

private func formatNumber(_ value: Double) -> String {
    let string = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    let trimmedZeros = string.replacingOccurrences(
        of: #"(\.\d*?)0+$"#,
        with: "$1",
        options: .regularExpression)
    return trimmedZeros.replacingOccurrences(
        of: #"\.$"#,
        with: "",
        options: .regularExpression)
}

private func parseOptions() -> BenchmarkOptions {
    let arguments = Array(CommandLine.arguments.dropFirst())
    var inputPath: String?
    var maxSurfaces: Int?
    var index = 0

    while index < arguments.count {
        switch arguments[index] {
        case "--input" where index + 1 < arguments.count:
            inputPath = arguments[index + 1]
            index += 2
        case "--max-surfaces" where index + 1 < arguments.count:
            maxSurfaces = Int(arguments[index + 1])
            index += 2
        default:
            index += 1
        }
    }

    return BenchmarkOptions(inputPath: inputPath, maxSurfaces: maxSurfaces)
}

private func defaultCityGMLPath() -> String? {
    let dataURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Benchmarks")
        .appendingPathComponent("data")
    let candidates = [
        "LoD3-HH_HafenCity_CityGML.gml",
        "LoD2_567_5931_1_HH.xml",
    ]

    for candidate in candidates {
        let path = dataURL.appendingPathComponent(candidate).path
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
    }
    return nil
}

private func loadDataset(options: BenchmarkOptions) throws -> BenchmarkDataset {
    if let path = options.inputPath ?? defaultCityGMLPath() {
        let wkts = try CityGMLSurfaceExtractor.extractWKTs(
            from: path,
            maxSurfaces: options.maxSurfaces)
        if !wkts.isEmpty {
            return BenchmarkDataset(
                name: URL(fileURLWithPath: path).lastPathComponent,
                source: path,
                wkts: wkts,
                isRealCityGML: true)
        }
        print("No CityGML building surfaces found in \(path); using generated fallback.")
    }

    let wkts = makeGeneratedCityGMLSurfaceWKTs(buildingCount: 20)
    return BenchmarkDataset(
        name: "generated CityGML-like surfaces",
        source: "generated",
        wkts: wkts,
        isRealCityGML: false)
}

private func prepareDataset(_ dataset: BenchmarkDataset) throws -> ([String], [Geometry], Int) {
    var acceptedWKTs: [String] = []
    var geometries: [Geometry] = []
    var rejected = 0

    acceptedWKTs.reserveCapacity(dataset.wkts.count)
    geometries.reserveCapacity(dataset.wkts.count)

    for wkt in dataset.wkts {
        do {
            let geometry = try Geometry.fromWKT(wkt)
            _ = try geometry.tesselate()
            acceptedWKTs.append(wkt)
            geometries.append(geometry)
        } catch {
            rejected += 1
        }
    }

    guard acceptedWKTs.count >= 100 || !dataset.isRealCityGML else {
        throw SFCGALError.operationFailed(
            "Only \(acceptedWKTs.count) usable CityGML surfaces were extracted; Issue 8.1 requires at least 100"
        )
    }

    return (acceptedWKTs, geometries, rejected)
}

private func estimatedVertexFloatCapacity(for wkts: [String]) -> Int {
    wkts.reduce(0) { total, wkt in
        let coordinateCount = wkt.reduce(1) { count, char in
            char == "," ? count + 1 : count
        }
        return total + max(9, coordinateCount * 9)
    }
}

private func makeGeneratedCityGMLSurfaceWKTs(buildingCount: Int = 20) -> [String] {
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
        surfaces.append(
            "POLYGON Z((\(x) \(y) 0,\(x2) \(y) 0,\(x2) \(y) \(height),\(x) \(y) \(height),\(x) \(y) 0))"
        )
        surfaces.append(
            "POLYGON Z((\(x2) \(y) 0,\(x2) \(y2) 0,\(x2) \(y2) \(height),\(x2) \(y) \(height),\(x2) \(y) 0))"
        )
        surfaces.append(
            "POLYGON Z((\(x2) \(y2) 0,\(x) \(y2) 0,\(x) \(y2) \(height),\(x2) \(y2) \(height),\(x2) \(y2) 0))"
        )
        surfaces.append(
            "POLYGON Z((\(x) \(y2) 0,\(x) \(y) 0,\(x) \(y) \(height),\(x) \(y2) \(height),\(x) \(y2) 0))"
        )
        surfaces.append(
            "POLYGON Z((\(x) \(y) \(height),\(x2) \(y) \(height),\(x2) \(midY) \(height + roofRise),\(x) \(midY) \(height + roofRise),\(x) \(y) \(height)))"
        )
    }

    return surfaces
}

private func run() throws {
    initializeSFCGAL()

    let options = parseOptions()
    let dataset = try loadDataset(options: options)
    let (wkts, geometries, rejectedCount) = try prepareDataset(dataset)
    let vertexCapacity = estimatedVertexFloatCapacity(for: wkts)

    print("Batch Operations Benchmark")
    print("Dataset: \(dataset.name)")
    print("Source: \(dataset.source)")
    print("Extracted surfaces: \(dataset.wkts.count)")
    print("Usable surfaces: \(wkts.count)")
    print("Rejected surfaces: \(rejectedCount)")
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
