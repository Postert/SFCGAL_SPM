#ifndef SFCGAL_SWIFT_SHIM_H
#define SFCGAL_SWIFT_SHIM_H

#include <SFCGAL/capi/sfcgal_c.h>

// Single source of truth for the required SFCGAL version.
// The compile-time check in version_check.cc enforces this at build time.
// Also visible to Swift via the CSFCGAL_Shim module.
#define SWIFTSFCGAL_REQUIRED_VERSION "2.2.0"

#endif /* SFCGAL_SWIFT_SHIM_H */
