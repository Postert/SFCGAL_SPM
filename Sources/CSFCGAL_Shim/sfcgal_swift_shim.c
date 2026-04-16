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

size_t sfcgal_swift_batch_tesselate(const sfcgal_geometry_t *const *geometries,
                                    size_t count,
                                    sfcgal_geometry_t **out_results) {
    size_t success = 0;
    for (size_t i = 0; i < count; i++) {
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
        }
    }
    return success;
}
