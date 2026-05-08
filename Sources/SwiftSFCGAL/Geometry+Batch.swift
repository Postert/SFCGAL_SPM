#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

/// Error thrown by batch geometry APIs when one or more input geometries fail.
public struct BatchGeometryError: Error, CustomStringConvertible {
    /// Maps input indexes to their per-geometry error messages.
    public let failures: [Int: String]

    public init(failures: [Int: String]) {
        self.failures = failures
    }

    public var description: String {
        let details = failures
            .sorted { $0.key < $1.key }
            .map { "index \($0.key): \($0.value)" }
            .joined(separator: "; ")
        return "SFCGAL batch operation failed: \(details)"
    }
}

/// Result of a batched WKT -> tesselated vertices pipeline.
public struct BatchVertexResult {
    /// Interleaved x,y,z float triples.
    public let vertices: [Float]

    /// Number of vertices produced for each input WKT.
    public let vertexCounts: [Int]

    public init(vertices: [Float], vertexCounts: [Int]) {
        self.vertices = vertices
        self.vertexCounts = vertexCounts
    }
}

/// Tesselates multiple geometries in one C-level call.
///
/// This avoids repeated Swift->C calls when processing large geometry batches,
/// such as many CityGML wall or roof surfaces. If any geometry fails, all
/// successful intermediate C results are released and a `BatchGeometryError`
/// reports the failed input indexes.
public func batchTesselate(_ geometries: [Geometry]) throws -> [Geometry] {
    guard !geometries.isEmpty else { return [] }

    let inputs: [UnsafeRawPointer?] = geometries.map { UnsafeRawPointer($0.handle) }
    var outputs = Array<UnsafeMutableRawPointer?>(repeating: nil, count: geometries.count)
    var errorPointers = Array<UnsafePointer<CChar>?>(repeating: nil, count: geometries.count)

    let successCount = inputs.withUnsafeBufferPointer { inputBuffer in
        outputs.withUnsafeMutableBufferPointer { outputBuffer in
            errorPointers.withUnsafeMutableBufferPointer { errorBuffer in
                sfcgal_swift_batch_tesselate_ex(
                    inputBuffer.baseAddress,
                    geometries.count,
                    outputBuffer.baseAddress,
                    errorBuffer.baseAddress)
            }
        }
    }

    guard Int(successCount) == geometries.count else {
        var failures: [Int: String] = [:]
        for (index, pointer) in errorPointers.enumerated() {
            if let pointer {
                failures[index] = String(cString: pointer)
            }
        }
        if failures.isEmpty, let pointer = sfcgal_swift_get_last_error() {
            failures[0] = String(cString: pointer)
        }
        if failures.isEmpty {
            failures[0] = "Batch tesselation failed"
        }
        for output in outputs {
            if let output {
                sfcgal_geometry_delete(output)
            }
        }
        throw BatchGeometryError(failures: failures)
    }

    if let missingIndex = outputs.firstIndex(where: { $0 == nil }) {
        for output in outputs {
            if let output {
                sfcgal_geometry_delete(output)
            }
        }
        throw BatchGeometryError(failures: [missingIndex: "Batch tesselation returned a NULL result"])
    }

    return outputs.map { makeGeometry(handle: $0!, ownsHandle: true) }
}

/// Parse WKT, tesselate, and extract interleaved x,y,z vertices in one C call.
///
/// `vertexCapacity` is measured in floats, not vertices. For example, a single
/// triangle needs capacity for 9 floats. If the buffer is too small, the
/// function throws and no partial Swift result is returned.
public func batchWKTToVertices(_ wktInputs: [String],
                               vertexCapacity: Int) throws -> BatchVertexResult {
    guard vertexCapacity >= 0 else {
        throw SFCGALError.operationFailed("vertexCapacity must be non-negative")
    }
    guard !wktInputs.isEmpty else {
        return BatchVertexResult(vertices: [], vertexCounts: [])
    }

    let cStrings = wktInputs.map { makeCString($0) }
    defer {
        for cString in cStrings {
            cString.pointer.deinitialize(count: cString.count)
            cString.pointer.deallocate()
        }
    }

    var inputPointers: [UnsafePointer<CChar>?] = cStrings.map { UnsafePointer($0.pointer) }
    var vertices = Array<Float>(repeating: 0, count: vertexCapacity)
    var vertexCounts = Array<Int>(repeating: 0, count: wktInputs.count)

    let floatsWritten = inputPointers.withUnsafeMutableBufferPointer { inputBuffer in
        vertices.withUnsafeMutableBufferPointer { vertexBuffer in
            vertexCounts.withUnsafeMutableBufferPointer { countBuffer in
                sfcgal_swift_batch_wkt_to_vertices(
                    inputBuffer.baseAddress,
                    wktInputs.count,
                    vertexBuffer.baseAddress,
                    countBuffer.baseAddress,
                    vertexCapacity)
            }
        }
    }

    if sfcgal_swift_has_error() != 0 {
        let message = sfcgal_swift_get_last_error().map(String.init(cString:))
            ?? "Batch WKT-to-vertices failed"
        throw SFCGALError.operationFailed(message)
    }

    vertices.removeSubrange(Int(floatsWritten)..<vertices.count)
    return BatchVertexResult(vertices: vertices, vertexCounts: vertexCounts)
}

private func makeCString(_ string: String) -> (pointer: UnsafeMutablePointer<CChar>, count: Int) {
    let utf8 = Array(string.utf8CString)
    let pointer = UnsafeMutablePointer<CChar>.allocate(capacity: utf8.count)
    for (index, char) in utf8.enumerated() {
        pointer.advanced(by: index).initialize(to: char)
    }
    return (pointer, utf8.count)
}
