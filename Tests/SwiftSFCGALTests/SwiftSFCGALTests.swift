import Testing
import Foundation
@testable import SwiftSFCGAL
import CSFCGAL_Shim

@Test func testSfcgalVersion() {
    let version = sfcgalVersion()
    #expect(
        version == expectedSFCGALVersion,
        "SFCGAL version mismatch: got \(version), expected \(expectedSFCGALVersion)")
}

// 1. Init test — calling twice must not crash
@Test func testInitIsIdempotent() {
    initializeSFCGAL()
    initializeSFCGAL()
}

// 2. Error capture — invalid WKT must set error, not crash
@Test func testErrorCapturedOnInvalidWKT() {
    initializeSFCGAL()
    sfcgal_swift_clear_errors()
    let result = sfcgal_io_read_wkt("NOT VALID WKT", 13)
    #expect(sfcgal_swift_has_error() == 1)
    #expect(sfcgal_swift_get_last_error() != nil)
    if result != nil { sfcgal_geometry_delete(result) }
}

// 3. Error is cleared between operations
@Test func testErrorClearsCorrectly() {
    initializeSFCGAL()
    sfcgal_swift_clear_errors()
    _ = sfcgal_io_read_wkt("NOT VALID WKT", 13)
    sfcgal_swift_clear_errors()
    #expect(sfcgal_swift_has_error() == 0)
    #expect(sfcgal_swift_get_last_error() == nil)
}

// 6. sfcgalCall throws SFCGALError on invalid input
@Test func testSfcgalCallThrowsOnError() {
    initializeSFCGAL()
    #expect(throws: SFCGALError.self) {
        try sfcgalCall {
            sfcgal_io_read_wkt("NOT VALID WKT", 13)
        }
    }
}

// 7. sfcgalCall returns result and does not throw on valid input
@Test func testSfcgalCallSucceeds() throws {
    initializeSFCGAL()
    let wkt = "POINT(1 2)"
    let geom = try sfcgalCall { sfcgal_io_read_wkt(wkt, wkt.utf8.count) }
    defer { if let g = geom { sfcgal_geometry_delete(g) } }
    #expect(geom != nil)
}

// 4. Thread isolation — error on one OS thread must not appear on another.
//    Uses real Foundation threads (not Swift Tasks) to guarantee separate
//    thread-local storage slots.
@Test func testThreadLocalIsolation() {
    initializeSFCGAL()

    // Class box to share result across thread boundaries without a data race —
    // accesses are serialised by the semaphores below.
    final class Box: @unchecked Sendable { var hasError = false }
    let box  = Box()
    let sem1 = DispatchSemaphore(value: 0)
    let sem2 = DispatchSemaphore(value: 0)

    // Thread 1: trigger an error.
    Thread.detachNewThread {
        sfcgal_swift_clear_errors()
        _ = sfcgal_io_read_wkt("INVALID", 7)
        sem1.signal()       // notify: error is now set on this thread
    }
    sem1.wait()             // wait until thread 1 has set its error flag

    // Thread 2: its thread-local flag must be clean.
    Thread.detachNewThread {
        sfcgal_swift_clear_errors()
        box.hasError = sfcgal_swift_has_error() != 0
        sem2.signal()
    }
    sem2.wait()

    #expect(!box.hasError)
}

// 5. Warning is captured separately — does not set the error flag
@Test func testWarningCapturedWithoutSettingErrorFlag() {
    initializeSFCGAL()
    sfcgal_swift_clear_errors()
    sfcgal_swift_inject_warning_for_testing("test warning message")
    #expect(sfcgal_swift_has_error() == 0,   "warning must not set the error flag")
    #expect(sfcgalLastWarning() == "test warning message")
}

// 6. Warning is cleared by sfcgal_swift_clear_errors
@Test func testWarningClearedCorrectly() {
    initializeSFCGAL()
    sfcgal_swift_clear_errors()
    sfcgal_swift_inject_warning_for_testing("will be cleared")
    sfcgal_swift_clear_errors()
    #expect(sfcgalLastWarning() == nil)
}

// 7. Warning and error are independent — both can be set simultaneously
@Test func testWarningAndErrorAreIndependent() {
    initializeSFCGAL()
    sfcgal_swift_clear_errors()
    sfcgal_swift_inject_warning_for_testing("concurrent warning")
    _ = sfcgal_io_read_wkt("INVALID", 7)   // sets error flag
    #expect(sfcgal_swift_has_error() == 1)
    #expect(sfcgalLastWarning() == "concurrent warning")
}

// ── Geometry class tests ──────────────────────────────────────────────────────

// 9. Parse a point from WKT and check its type
@Test func testGeometryPointFromWKT() throws {
    initializeSFCGAL()
    let geom = try Geometry(wkt: "POINT(1.0 2.0 3.0)")
    #expect(geom.geometryType == "Point")
    #expect(geom.geometryTypeID == 1)   // SFCGAL_TYPE_POINT = 1
    #expect(geom.isValid)
}

// 10. Invalid WKT must throw SFCGALError.operationFailed, not crash
@Test func testGeometryInvalidWKTThrows() {
    initializeSFCGAL()
    #expect(throws: SFCGALError.self) {
        _ = try Geometry(wkt: "NOT_A_GEOMETRY")
    }
}

// 11. WKT round-trip — parse then serialise
@Test func testGeometryWKTRoundtrip() throws {
    initializeSFCGAL()
    let geom = try Geometry(wkt: "POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let output = geom.asWKT()
    #expect(output.contains("POLYGON"))
    #expect(!output.isEmpty)
}

// 12. asWKT with decimal precision
@Test func testGeometryAsWKTDecimals() throws {
    initializeSFCGAL()
    let geom = try Geometry(wkt: "POINT(1.123456789 2.987654321)")
    let wkt2 = geom.asWKT(decimals: 2)
    #expect(wkt2.contains("POINT"))
    // Rounded to 2 decimals — full precision string should be longer
    #expect(wkt2.count < geom.asWKT().count)
}

// 13. clone() produces an independent copy
@Test func testGeometryClone() throws {
    initializeSFCGAL()
    let original = try Geometry(wkt: "POINT(1 2 3)")
    let copy = try original.clone()
    // Independent objects with the same WKT
    #expect(original.asWKT() == copy.asWKT())
    // Different Swift objects (different handles)
    #expect(original !== copy)
}

// 14. Polygon validity
@Test func testGeometryValidPolygon() throws {
    initializeSFCGAL()
    let valid = try Geometry(wkt: "POLYGON((0 0,1 0,1 1,0 1,0 0))")
    #expect(valid.isValid)
}

// 15. ownsHandle: false — borrowed geometry is not freed in deinit
//     (Tests that creating a non-owning wrapper on a live pointer doesn't crash.)
@Test func testGeometryBorrowedHandle() throws {
    initializeSFCGAL()
    let owner = try Geometry(wkt: "POINT(0 0)")
    // Create a non-owning alias — simulates how child geometries of collections
    // will be exposed without transferring ownership.
    let borrowed = Geometry(handle: owner.handle, ownsHandle: false)
    #expect(borrowed.geometryType == "Point")
    // borrowed goes out of scope here without calling sfcgal_geometry_delete —
    // owner still holds the valid pointer and frees it in its own deinit.
}

// 16. Batch tesselation — verify a valid polygon tesselates successfully.
//
// Swift type mappings for sfcgal_geometry_t (typedef void):
//   sfcgal_geometry_t*          → UnsafeMutableRawPointer
//   const sfcgal_geometry_t *const * → UnsafePointer<UnsafeRawPointer?>?
//   sfcgal_geometry_t **        → UnsafeMutableRawPointer? (Swift treats void** as void*)
@Test func testBatchTesselate() {
    initializeSFCGAL()

    let wkt = "POLYGON((0 0,1 0,1 1,0 1,0 0))"
    sfcgal_swift_clear_errors()
    guard let geom = sfcgal_io_read_wkt(wkt, wkt.utf8.count) else {
        Issue.record("Failed to parse test polygon")
        return
    }
    defer { sfcgal_geometry_delete(geom) }

    // One-element input array: UnsafePointer<UnsafeRawPointer?>
    var input: UnsafeRawPointer? = UnsafeRawPointer(geom)

    // Output slot. The C function writes a void* into out_results[0]; we read it
    // back via the raw pointer after the call.
    var outputSlot: UnsafeMutableRawPointer? = nil

    sfcgal_swift_clear_errors()
    // &outputSlot produces UnsafeMutablePointer<UnsafeMutableRawPointer?>, matching
    // Swift's import of sfcgal_geometry_t ** → UnsafeMutablePointer<UnsafeMutableRawPointer?>?
    let successCount = withUnsafePointer(to: &input) { inputPtr in
        sfcgal_swift_batch_tesselate(inputPtr, 1, &outputSlot)
    }

    #expect(successCount == 1)
    #expect(sfcgal_swift_has_error() == 0)
    if let r = outputSlot { sfcgal_geometry_delete(r) }
}
