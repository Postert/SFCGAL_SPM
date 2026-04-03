#!/usr/bin/env bash
#
# create-xcframeworks.sh
#
# Creates XCFrameworks for GMP, MPFR, and SFCGAL from the cross-compiled
# iOS builds produced by build-gmp-ios.sh, build-mpfr-ios.sh, and
# build-sfcgal-ios.sh.
#
# Each XCFramework contains:
#   - iOS device slice (arm64)
#   - iOS simulator slice (arm64 + x86_64 fat binary)
#   - Module map for Swift interop
#
# Prerequisites:
#   - Run build-gmp-ios.sh, build-mpfr-ios.sh, build-sfcgal-ios.sh first
#   - Xcode command line tools installed
#
# Usage:
#   ./scripts/create-xcframeworks.sh
#
# Output:
#   xcframeworks/GMP.xcframework
#   xcframeworks/MPFR.xcframework
#   xcframeworks/SFCGAL.xcframework

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

GMP_BUILD="${PROJECT_DIR}/gmp-ios-build"
MPFR_BUILD="${PROJECT_DIR}/mpfr-ios-build"
SFCGAL_BUILD="${PROJECT_DIR}/sfcgal-ios-build"
OUTPUT_DIR="${PROJECT_DIR}/xcframeworks"

# ─── Validation ───────────────────────────────────────────────────────────────

echo "=== Validating cross-compiled builds ==="

for lib_build in "$GMP_BUILD" "$MPFR_BUILD" "$SFCGAL_BUILD"; do
    lib_name=$(basename "$lib_build")
    for variant in ios-arm64 simulator-fat; do
        if [ ! -d "${lib_build}/${variant}" ]; then
            echo "ERROR: Missing ${lib_name}/${variant}. Run the build scripts first."
            exit 1
        fi
    done
done

echo "All build outputs found."

# ─── Prepare output directory ─────────────────────────────────────────────────

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Use a temporary directory for staged headers (with module maps injected)
STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

# ─── Helper: stage headers with module map ────────────────────────────────────

stage_headers() {
    local src_include="$1"    # e.g., gmp-ios-build/ios-arm64/include
    local dest_dir="$2"       # staging directory for this slice
    local modulemap="$3"      # module map content

    mkdir -p "$dest_dir"
    cp -R "$src_include"/* "$dest_dir"/
    echo "$modulemap" > "$dest_dir/module.modulemap"
}

# ─── GMP XCFramework ─────────────────────────────────────────────────────────

echo ""
echo "=== Creating GMP.xcframework ==="

# GMP and MPFR don't get module maps — they are link-time dependencies only.
# The SFCGAL module map includes `link "gmp"` and `link "mpfr"` directives
# so the linker finds them. Omitting module maps avoids the Xcode build error
# "Multiple commands produce .../include/module.modulemap" when multiple
# xcframeworks each ship their own module.modulemap.

GMP_IOS_HEADERS="${STAGING_DIR}/gmp-ios-arm64-headers"
GMP_SIM_HEADERS="${STAGING_DIR}/gmp-sim-fat-headers"

mkdir -p "$GMP_IOS_HEADERS" "$GMP_SIM_HEADERS"
cp -R "${GMP_BUILD}/ios-arm64/include"/* "$GMP_IOS_HEADERS"/
cp -R "${GMP_BUILD}/simulator-arm64/include"/* "$GMP_SIM_HEADERS"/

xcodebuild -create-xcframework \
    -library "${GMP_BUILD}/ios-arm64/lib/libgmp.a" \
    -headers "$GMP_IOS_HEADERS" \
    -library "${GMP_BUILD}/simulator-fat/lib/libgmp.a" \
    -headers "$GMP_SIM_HEADERS" \
    -output "${OUTPUT_DIR}/GMP.xcframework"

echo "Created GMP.xcframework"

# ─── MPFR XCFramework ────────────────────────────────────────────────────────

echo ""
echo "=== Creating MPFR.xcframework ==="

MPFR_IOS_HEADERS="${STAGING_DIR}/mpfr-ios-arm64-headers"
MPFR_SIM_HEADERS="${STAGING_DIR}/mpfr-sim-fat-headers"

mkdir -p "$MPFR_IOS_HEADERS" "$MPFR_SIM_HEADERS"
cp -R "${MPFR_BUILD}/ios-arm64/include"/* "$MPFR_IOS_HEADERS"/
cp -R "${MPFR_BUILD}/simulator-arm64/include"/* "$MPFR_SIM_HEADERS"/

xcodebuild -create-xcframework \
    -library "${MPFR_BUILD}/ios-arm64/lib/libmpfr.a" \
    -headers "$MPFR_IOS_HEADERS" \
    -library "${MPFR_BUILD}/simulator-fat/lib/libmpfr.a" \
    -headers "$MPFR_SIM_HEADERS" \
    -output "${OUTPUT_DIR}/MPFR.xcframework"

echo "Created MPFR.xcframework"

# ─── SFCGAL XCFramework ──────────────────────────────────────────────────────

echo ""
echo "=== Creating SFCGAL.xcframework ==="

# The SFCGAL module map exposes only the C API header. It includes
# SFCGAL/config.h and SFCGAL/export.h transitively.
# We define SFCGAL_USE_STATIC_LIBS so that SFCGAL_API resolves to nothing
# (correct for static linking — no dllimport/dllexport).
SFCGAL_MODULEMAP="module CSFCGAL_Binary {
    header \"SFCGAL/capi/sfcgal_c.h\"
    link \"SFCGAL\"
    link \"gmp\"
    link \"mpfr\"
    export *
}"

SFCGAL_IOS_HEADERS="${STAGING_DIR}/sfcgal-ios-arm64-headers"
SFCGAL_SIM_HEADERS="${STAGING_DIR}/sfcgal-sim-fat-headers"

stage_headers "${SFCGAL_BUILD}/ios-arm64/include" "$SFCGAL_IOS_HEADERS" "$SFCGAL_MODULEMAP"
stage_headers "${SFCGAL_BUILD}/simulator-arm64/include" "$SFCGAL_SIM_HEADERS" "$SFCGAL_MODULEMAP"

xcodebuild -create-xcframework \
    -library "${SFCGAL_BUILD}/ios-arm64/lib/libSFCGAL.a" \
    -headers "$SFCGAL_IOS_HEADERS" \
    -library "${SFCGAL_BUILD}/simulator-fat/lib/libSFCGAL.a" \
    -headers "$SFCGAL_SIM_HEADERS" \
    -output "${OUTPUT_DIR}/SFCGAL.xcframework"

echo "Created SFCGAL.xcframework"

# ─── Verification ─────────────────────────────────────────────────────────────

echo ""
echo "=== Verifying XCFrameworks ==="

for fw in GMP MPFR SFCGAL; do
    fw_path="${OUTPUT_DIR}/${fw}.xcframework"
    echo ""
    echo "--- ${fw}.xcframework ---"

    if [ ! -d "$fw_path" ]; then
        echo "ERROR: ${fw}.xcframework not found!"
        exit 1
    fi

    # Show Info.plist summary
    echo "Slices:"
    plutil -p "${fw_path}/Info.plist" | grep -E "LibraryIdentifier|LibraryPath|SupportedArchitectures|SupportedPlatform" || true

    # Check architectures in each .a file
    find "$fw_path" -name "*.a" | while read -r lib; do
        echo ""
        echo "  $(echo "$lib" | sed "s|${OUTPUT_DIR}/||")"
        lipo -info "$lib"
    done

    # Verify module map exists in each slice
    find "$fw_path" -name "module.modulemap" | while read -r mm; do
        echo "  Module map: $(echo "$mm" | sed "s|${OUTPUT_DIR}/||")"
    done
done

echo ""
echo "=== Done ==="
echo "XCFrameworks created in: ${OUTPUT_DIR}/"
echo ""
echo "Contents:"
ls -1 "${OUTPUT_DIR}/"
