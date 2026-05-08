#ifndef SFCGAL_SWIFT_SHIM_H
#define SFCGAL_SWIFT_SHIM_H

#include <SFCGAL/capi/sfcgal_c.h>
#include <stddef.h>

// Single source of truth for the required SFCGAL version.
// The compile-time check in version_check.cc enforces this at build time.
// Also visible to Swift via the CSFCGAL_Shim module.
#define SWIFTSFCGAL_REQUIRED_VERSION "2.2.0"

// ── Error handling shim ───────────────────────────────────────────────────────

/// Initialize SFCGAL with custom warning/error handlers that capture messages
/// into thread-local buffers instead of calling abort(). Safe to call multiple
/// times — only initializes once. Must be called from the main thread before
/// spawning any threads that use SFCGAL.
void sfcgal_swift_init(void);

/// Returns the last captured error message, or NULL if no error since the last
/// call to sfcgal_swift_clear_errors().
const char *sfcgal_swift_get_last_error(void);

/// Returns the last captured warning message, or NULL if no warning since the
/// last call to sfcgal_swift_clear_errors().
const char *sfcgal_swift_get_last_warning(void);

/// Clears both the error and warning buffers. Call this before each SFCGAL
/// operation so the result reflects only that operation.
void sfcgal_swift_clear_errors(void);

/// Returns 1 if an error was captured since the last sfcgal_swift_clear_errors(),
/// 0 otherwise.
int sfcgal_swift_has_error(void);

/// Free a buffer that was allocated by SFCGAL (e.g. the WKT string returned by
/// sfcgal_geometry_as_text, or the type string from sfcgal_geometry_type).
/// Using this instead of calling free() directly keeps Swift files free of
/// platform-specific libc imports (Darwin / Glibc / WinSDK).
void sfcgal_swift_free_buffer(void *ptr);

/// Injects a warning message into the thread-local warning buffer.
/// Only intended for unit testing the warning capture path — do not call in
/// production code.
void sfcgal_swift_inject_warning_for_testing(const char *message);

// ── Batch operations shim ─────────────────────────────────────────────────────

/// Tesselate multiple geometry objects in one C-level call, avoiding per-call
/// Swift->C overhead in tight loops (e.g. CityGML surface processing).
///
/// - geometries:  array of `count` valid sfcgal_geometry_t* (ownership NOT transferred)
/// - count:       number of geometries
/// - out_results: caller-allocated array of `count` sfcgal_geometry_t*
///                Each non-NULL entry must be freed with sfcgal_geometry_delete().
///                On failure for geometry i, out_results[i] is set to NULL.
///
/// The error buffer reflects the last failure encountered. Call
/// sfcgal_swift_clear_errors() before invoking this function, then check
/// sfcgal_swift_has_error() afterward to detect any failures.
///
/// Returns the number of geometries successfully tesselated.
size_t sfcgal_swift_batch_tesselate(const sfcgal_geometry_t *const *geometries,
                                    size_t count,
                                    sfcgal_geometry_t **out_results);

/// Like sfcgal_swift_batch_tesselate, but also fills out_errors[i] with a
/// pointer to a thread-local static error string for each failed geometry
/// (NULL on success). Strings are valid until the next call on this thread.
///
/// Returns the number of geometries successfully tesselated.
size_t sfcgal_swift_batch_tesselate_ex(
    const sfcgal_geometry_t *const *geometries,
    size_t count,
    sfcgal_geometry_t **out_results,
    const char **out_errors);

/// Parse WKT -> tesselate -> extract interleaved x,y,z vertex data in one call.
/// Designed for GPU upload pipelines (e.g. CityGML surfaces -> RealityKit mesh).
///
/// out_vertices:      caller-allocated float buffer (interleaved x,y,z triples)
/// out_vertex_counts: caller-allocated array of count size_t slots;
///                    out_vertex_counts[i] is the number of vertices for geometry i
/// out_capacity:      total capacity of out_vertices in number of floats
///
/// Returns total floats written, or 0 on complete failure. Check
/// sfcgal_swift_has_error() for partial failures.
size_t sfcgal_swift_batch_wkt_to_vertices(
    const char **wkt_inputs,
    size_t count,
    float *out_vertices,
    size_t *out_vertex_counts,
    size_t out_capacity);

#endif /* SFCGAL_SWIFT_SHIM_H */
