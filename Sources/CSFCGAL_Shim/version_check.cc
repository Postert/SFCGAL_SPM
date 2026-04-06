// Compile-time check that the system SFCGAL version matches SwiftSFCGAL.
// This file is C++ because SFCGAL/version.h contains C++ code (namespace).

#include <SFCGAL/version.h>
#include "include/sfcgal_swift_shim.h"

static_assert(
    __builtin_strcmp(SFCGAL_VERSION, SWIFTSFCGAL_REQUIRED_VERSION) == 0,
    "SFCGAL version mismatch: SwiftSFCGAL requires exactly SFCGAL " SWIFTSFCGAL_REQUIRED_VERSION
    ", but found " SFCGAL_VERSION " installed on this system"
);
