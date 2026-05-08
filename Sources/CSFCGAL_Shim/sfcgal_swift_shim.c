// C shim layer between SFCGAL's C API and Swift.
//
// Responsibilities:
//   1. Install a custom error/warning handler so SFCGAL never calls abort().
//      Errors are captured into thread-local buffers; Swift retrieves them and
//      throws proper Swift errors.
//   2. Provide a batch tesselation function that processes an array of geometry
//      objects in a single C call, avoiding per-call Swift->C overhead.

#include "sfcgal_swift_shim.h"
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>

// _Thread_local is C11. MSVC uses __declspec(thread) in C mode.
#ifdef _MSC_VER
  #define THREAD_LOCAL __declspec(thread)
#else
  #define THREAD_LOCAL _Thread_local
#endif

// Per-thread buffers. Large enough for any SFCGAL diagnostic message.
static THREAD_LOCAL char sfcgal_error_buf[2048]   = {0};
static THREAD_LOCAL char sfcgal_warning_buf[2048] = {0};
static THREAD_LOCAL int  sfcgal_error_flag        = 0;
static THREAD_LOCAL char (*sfcgal_batch_error_bufs)[2048] = NULL;
static THREAD_LOCAL size_t sfcgal_batch_error_capacity = 0;

// sfcgal_error_handler_t is: int (*)(const char *fmt, ...)
// Return value is ignored by SFCGAL; we return 0.
static int swift_error_handler(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vsnprintf(sfcgal_error_buf, sizeof(sfcgal_error_buf), fmt, args);
    va_end(args);
    sfcgal_error_flag = 1;
    // Do NOT call abort() — let Swift handle the error gracefully.
    return 0;
}

static int swift_warning_handler(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vsnprintf(sfcgal_warning_buf, sizeof(sfcgal_warning_buf), fmt, args);
    va_end(args);
    // Warnings do not set sfcgal_error_flag — they are informational only.
    return 0;
}

void sfcgal_swift_init(void) {
    // Not atomic — must be called from the main thread before any threads that
    // use SFCGAL are spawned. Calling twice from a single thread is safe.
    static int initialized = 0;
    if (initialized) return;
    initialized = 1;
    sfcgal_init();
    // warning handler first, error handler second — matches the parameter order
    // of sfcgal_set_error_handlers(warning_handler, error_handler).
    sfcgal_set_error_handlers(swift_warning_handler, swift_error_handler);
}

const char *sfcgal_swift_get_last_error(void) {
    return sfcgal_error_flag ? sfcgal_error_buf : NULL;
}

const char *sfcgal_swift_get_last_warning(void) {
    return sfcgal_warning_buf[0] != '\0' ? sfcgal_warning_buf : NULL;
}

void sfcgal_swift_clear_errors(void) {
    sfcgal_error_flag     = 0;
    sfcgal_error_buf[0]   = '\0';
    sfcgal_warning_buf[0] = '\0';
}

int sfcgal_swift_has_error(void) {
    return sfcgal_error_flag;
}

void sfcgal_swift_free_buffer(void *ptr) {
    free(ptr);
}

void sfcgal_swift_inject_warning_for_testing(const char *message) {
    swift_warning_handler("%s", message);
}

static void sfcgal_swift_set_last_error_message(const char *message) {
    if (message == NULL || message[0] == '\0') {
        message = "Unknown SFCGAL error";
    }
    snprintf(sfcgal_error_buf, sizeof(sfcgal_error_buf), "%s", message);
    sfcgal_error_flag = 1;
}

static const char *sfcgal_swift_current_error_or(const char *fallback) {
    const char *message = sfcgal_swift_get_last_error();
    if (message == NULL || message[0] == '\0') {
        return fallback;
    }
    return message;
}

static int sfcgal_swift_ensure_batch_error_capacity(size_t count) {
    if (count <= sfcgal_batch_error_capacity) {
        return 1;
    }

    char (*new_bufs)[2048] = (char (*)[2048])realloc(
        sfcgal_batch_error_bufs,
        count * sizeof(*sfcgal_batch_error_bufs));
    if (new_bufs == NULL) {
        sfcgal_swift_set_last_error_message("Unable to allocate batch error storage");
        return 0;
    }

    sfcgal_batch_error_bufs = new_bufs;
    sfcgal_batch_error_capacity = count;
    return 1;
}

static const char *sfcgal_swift_store_batch_error(size_t index,
                                                  const char *message) {
    snprintf(sfcgal_batch_error_bufs[index],
             sizeof(sfcgal_batch_error_bufs[index]),
             "%s",
             message == NULL ? "Unknown SFCGAL error" : message);
    return sfcgal_batch_error_bufs[index];
}

static void sfcgal_swift_remember_failure(char *last_error,
                                          size_t last_error_size,
                                          const char *message) {
    snprintf(last_error,
             last_error_size,
             "%s",
             message == NULL ? "Unknown SFCGAL error" : message);
}

size_t sfcgal_swift_batch_tesselate(const sfcgal_geometry_t *const *geometries,
                                    size_t count,
                                    sfcgal_geometry_t **out_results) {
    return sfcgal_swift_batch_tesselate_ex(geometries, count, out_results, NULL);
}

size_t sfcgal_swift_batch_tesselate_ex(
    const sfcgal_geometry_t *const *geometries,
    size_t count,
    sfcgal_geometry_t **out_results,
    const char **out_errors) {
    if (count == 0) {
        return 0;
    }

    if (geometries == NULL || out_results == NULL) {
        sfcgal_swift_set_last_error_message("Batch tesselate received NULL input arrays");
        return 0;
    }

    if (out_errors != NULL && !sfcgal_swift_ensure_batch_error_capacity(count)) {
        return 0;
    }

    size_t success = 0;
    int had_failure = 0;
    char last_error[2048] = {0};

    for (size_t i = 0; i < count; i++) {
        out_results[i] = NULL;
        if (out_errors != NULL) {
            out_errors[i] = NULL;
        }
    }

    for (size_t i = 0; i < count; i++) {
        if (geometries[i] == NULL) {
            const char *message = "Input geometry is NULL";
            if (out_errors != NULL) {
                out_errors[i] = sfcgal_swift_store_batch_error(i, message);
            }
            sfcgal_swift_remember_failure(last_error, sizeof(last_error), message);
            had_failure = 1;
            continue;
        }

        sfcgal_swift_clear_errors();
        out_results[i] = sfcgal_geometry_tesselate(geometries[i]);
        if (out_results[i] != NULL && !sfcgal_swift_has_error()) {
            success++;
        } else {
            // Ensure a failed slot is always NULL so the caller can check safely.
            if (out_results[i] != NULL) {
                sfcgal_geometry_delete(out_results[i]);
                out_results[i] = NULL;
            }
            const char *message = sfcgal_swift_current_error_or("Tesselation failed");
            if (out_errors != NULL) {
                out_errors[i] = sfcgal_swift_store_batch_error(i, message);
            }
            sfcgal_swift_remember_failure(last_error, sizeof(last_error), message);
            had_failure = 1;
        }
    }

    if (had_failure) {
        sfcgal_swift_set_last_error_message(last_error);
    } else {
        sfcgal_swift_clear_errors();
    }

    return success;
}

static size_t sfcgal_swift_count_vertices(const sfcgal_geometry_t *geometry) {
    if (geometry == NULL) {
        return 0;
    }

    switch (sfcgal_geometry_type_id(geometry)) {
    case SFCGAL_TYPE_TRIANGLE:
        return 3;
    case SFCGAL_TYPE_TRIANGULATEDSURFACE:
        return sfcgal_triangulated_surface_num_patches(geometry) * 3;
    case SFCGAL_TYPE_GEOMETRYCOLLECTION: {
        size_t total = 0;
        size_t count = sfcgal_geometry_num_geometries(geometry);
        for (size_t i = 0; i < count; i++) {
            const sfcgal_geometry_t *child =
                sfcgal_geometry_collection_geometry_n(geometry, i);
            total += sfcgal_swift_count_vertices(child);
        }
        return total;
    }
    default:
        return 0;
    }
}

static size_t sfcgal_swift_append_triangle_vertices(const sfcgal_geometry_t *triangle,
                                                    float *out_vertices,
                                                    size_t offset,
                                                    size_t out_capacity) {
    if (triangle == NULL || out_vertices == NULL || offset + 9 > out_capacity) {
        return (size_t)-1;
    }

    for (int i = 0; i < 3; i++) {
        const sfcgal_geometry_t *point = sfcgal_triangle_vertex(triangle, i);
        if (point == NULL) {
            return (size_t)-1;
        }

        out_vertices[offset++] = (float)sfcgal_point_x(point);
        out_vertices[offset++] = (float)sfcgal_point_y(point);
        out_vertices[offset++] =
            sfcgal_geometry_is_3d(point) ? (float)sfcgal_point_z(point) : 0.0f;
    }

    return 9;
}

static size_t sfcgal_swift_append_vertices(const sfcgal_geometry_t *geometry,
                                           float *out_vertices,
                                           size_t offset,
                                           size_t out_capacity) {
    if (geometry == NULL) {
        return 0;
    }

    switch (sfcgal_geometry_type_id(geometry)) {
    case SFCGAL_TYPE_TRIANGLE:
        return sfcgal_swift_append_triangle_vertices(
            geometry,
            out_vertices,
            offset,
            out_capacity);
    case SFCGAL_TYPE_TRIANGULATEDSURFACE: {
        size_t written = 0;
        size_t count = sfcgal_triangulated_surface_num_patches(geometry);
        for (size_t i = 0; i < count; i++) {
            const sfcgal_geometry_t *triangle =
                sfcgal_triangulated_surface_patch_n(geometry, i);
            size_t n = sfcgal_swift_append_triangle_vertices(
                triangle,
                out_vertices,
                offset + written,
                out_capacity);
            if (n == (size_t)-1) {
                return (size_t)-1;
            }
            written += n;
        }
        return written;
    }
    case SFCGAL_TYPE_GEOMETRYCOLLECTION: {
        size_t written = 0;
        size_t count = sfcgal_geometry_num_geometries(geometry);
        for (size_t i = 0; i < count; i++) {
            const sfcgal_geometry_t *child =
                sfcgal_geometry_collection_geometry_n(geometry, i);
            size_t n = sfcgal_swift_append_vertices(
                child,
                out_vertices,
                offset + written,
                out_capacity);
            if (n == (size_t)-1) {
                return (size_t)-1;
            }
            written += n;
        }
        return written;
    }
    default:
        return 0;
    }
}

size_t sfcgal_swift_batch_wkt_to_vertices(
    const char **wkt_inputs,
    size_t count,
    float *out_vertices,
    size_t *out_vertex_counts,
    size_t out_capacity) {
    if (count == 0) {
        return 0;
    }

    if (wkt_inputs == NULL || out_vertex_counts == NULL ||
        (out_capacity > 0 && out_vertices == NULL)) {
        sfcgal_swift_set_last_error_message("Batch WKT-to-vertices received NULL input arrays");
        return 0;
    }

    for (size_t i = 0; i < count; i++) {
        out_vertex_counts[i] = 0;
    }

    size_t total_floats = 0;
    int had_failure = 0;
    char last_error[2048] = {0};

    for (size_t i = 0; i < count; i++) {
        if (wkt_inputs[i] == NULL) {
            const char *message = "Input WKT is NULL";
            sfcgal_swift_remember_failure(last_error, sizeof(last_error), message);
            had_failure = 1;
            continue;
        }

        sfcgal_swift_clear_errors();
        sfcgal_geometry_t *geometry =
            sfcgal_io_read_wkt(wkt_inputs[i], strlen(wkt_inputs[i]));
        if (geometry == NULL || sfcgal_swift_has_error()) {
            if (geometry != NULL) {
                sfcgal_geometry_delete(geometry);
            }
            const char *message = sfcgal_swift_current_error_or("Failed to parse WKT");
            sfcgal_swift_remember_failure(last_error, sizeof(last_error), message);
            had_failure = 1;
            continue;
        }

        sfcgal_swift_clear_errors();
        sfcgal_geometry_t *tessellated = sfcgal_geometry_tesselate(geometry);
        sfcgal_geometry_delete(geometry);
        if (tessellated == NULL || sfcgal_swift_has_error()) {
            if (tessellated != NULL) {
                sfcgal_geometry_delete(tessellated);
            }
            const char *message = sfcgal_swift_current_error_or("Tesselation failed");
            sfcgal_swift_remember_failure(last_error, sizeof(last_error), message);
            had_failure = 1;
            continue;
        }

        size_t vertex_count = sfcgal_swift_count_vertices(tessellated);
        size_t float_count = vertex_count * 3;
        if (vertex_count > 0 && float_count / 3 != vertex_count) {
            sfcgal_geometry_delete(tessellated);
            const char *message = "Vertex count overflow";
            sfcgal_swift_remember_failure(last_error, sizeof(last_error), message);
            had_failure = 1;
            continue;
        }

        if (float_count > out_capacity - total_floats) {
            sfcgal_geometry_delete(tessellated);
            const char *message = "Output vertex buffer capacity exceeded";
            sfcgal_swift_remember_failure(last_error, sizeof(last_error), message);
            had_failure = 1;
            continue;
        }

        size_t written = sfcgal_swift_append_vertices(
            tessellated,
            out_vertices,
            total_floats,
            out_capacity);
        sfcgal_geometry_delete(tessellated);
        if (written == (size_t)-1 || written != float_count) {
            const char *message = "Failed to extract tesselated vertices";
            sfcgal_swift_remember_failure(last_error, sizeof(last_error), message);
            had_failure = 1;
            continue;
        }

        out_vertex_counts[i] = vertex_count;
        total_floats += written;
    }

    if (had_failure) {
        sfcgal_swift_set_last_error_message(last_error);
    } else {
        sfcgal_swift_clear_errors();
    }

    return total_floats;
}
