#!/usr/bin/env bash
#
# build-sfcgal-ios.sh — Cross-compile SFCGAL for iOS device and simulator
#
# Downloads CGAL (header-only), Boost (builds thread/system/serialization),
# then builds SFCGAL as a static library using CMake with an iOS toolchain.
#
# Produces:
#   $OUTPUT_DIR/ios-arm64/          — device (arm64, platform IOS)
#   $OUTPUT_DIR/simulator-arm64/    — simulator Apple Silicon (arm64, platform IOS_SIMULATOR)
#   $OUTPUT_DIR/simulator-x86_64/   — simulator Intel (x86_64, platform IOS_SIMULATOR)
#   $OUTPUT_DIR/simulator-fat/      — merged simulator (arm64 + x86_64)
#
# Usage:
#   ./scripts/build-sfcgal-ios.sh <gmp_dir> <mpfr_dir> [output_dir]
#
#   gmp_dir:    path to GMP cross-compiled output (from build-gmp-ios.sh)
#   mpfr_dir:   path to MPFR cross-compiled output (from build-mpfr-ios.sh)
#   output_dir: where to place SFCGAL builds (default: ./sfcgal-ios-build)
#
# Requirements:
#   - Xcode (not just Command Line Tools) for iOS SDKs
#   - CMake 3.21+
#   - Cross-compiled GMP and MPFR (run build-gmp-ios.sh and build-mpfr-ios.sh first)
#   - curl, tar, lipo, otool
#
# Patches applied to SFCGAL source:
#   - Removes hard-coded set(Boost_USE_STATIC_LIBS OFF) so the cache variable
#     from our -DBoost_USE_STATIC_LIBS=ON takes effect.

set -euo pipefail

SFCGAL_VERSION="${SFCGAL_VERSION_OVERRIDE:-2.0.0}"
SFCGAL_URL="https://gitlab.com/sfcgal/SFCGAL/-/archive/v${SFCGAL_VERSION}/SFCGAL-v${SFCGAL_VERSION}.tar.gz"
CGAL_VERSION="6.0.1"
CGAL_URL="https://github.com/CGAL/cgal/releases/download/v${CGAL_VERSION}/CGAL-${CGAL_VERSION}.tar.xz"
BOOST_VERSION="1.87.0"
BOOST_VERSION_UNDERSCORE="1_87_0"
BOOST_URLS=(
    "https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION_UNDERSCORE}.tar.gz"
    "https://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION}/boost_${BOOST_VERSION_UNDERSCORE}.tar.gz/download"
)
IOS_MIN_VERSION="15.0"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <gmp_dir> <mpfr_dir> [output_dir]"
    echo "  gmp_dir:    path to GMP cross-compiled output (from build-gmp-ios.sh)"
    echo "  mpfr_dir:   path to MPFR cross-compiled output (from build-mpfr-ios.sh)"
    echo "  output_dir: where to place SFCGAL builds (default: ./sfcgal-ios-build)"
    exit 1
fi

GMP_DIR="$(cd "$1" && pwd)"
MPFR_DIR="$(cd "$2" && pwd)"
OUTPUT_DIR="$(mkdir -p "${3:-$(pwd)/sfcgal-ios-build}" && cd "${3:-$(pwd)/sfcgal-ios-build}" && pwd)"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

NCPU=$(sysctl -n hw.ncpu)

# Download with retry and fallback mirrors
download_with_retry() {
    local output="$1"
    shift
    local urls=("$@")
    for url in "${urls[@]}"; do
        echo "  Trying: $url"
        if curl -fSL --retry 3 --retry-delay 5 --connect-timeout 30 "$url" -o "$output"; then
            echo "  Downloaded from: $url"
            return 0
        fi
        echo "  Failed, trying next mirror..."
    done
    echo "ERROR: All download mirrors failed."
    exit 1
}

# Validate GMP and MPFR builds exist
for variant in ios-arm64 simulator-arm64 simulator-x86_64; do
    if [ ! -f "$GMP_DIR/$variant/lib/libgmp.a" ]; then
        echo "ERROR: Missing GMP build at $GMP_DIR/$variant/lib/libgmp.a"
        echo "Run build-gmp-ios.sh first."
        exit 1
    fi
    if [ ! -f "$MPFR_DIR/$variant/lib/libmpfr.a" ]; then
        echo "ERROR: Missing MPFR build at $MPFR_DIR/$variant/lib/libmpfr.a"
        echo "Run build-mpfr-ios.sh first."
        exit 1
    fi
done

if ! command -v cmake &> /dev/null; then
    echo "ERROR: cmake not found. Install with: brew install cmake"
    exit 1
fi

# =============================================================================
# Download dependencies
# =============================================================================

echo "=== Downloading SFCGAL ${SFCGAL_VERSION} ==="
download_with_retry "$WORK_DIR/sfcgal.tar.gz" "$SFCGAL_URL"
tar xf "$WORK_DIR/sfcgal.tar.gz" -C "$WORK_DIR"
SFCGAL_SRC="$WORK_DIR/SFCGAL-v${SFCGAL_VERSION}"

echo "=== Downloading CGAL ${CGAL_VERSION} (headers only) ==="
download_with_retry "$WORK_DIR/cgal.tar.xz" "$CGAL_URL"
tar xf "$WORK_DIR/cgal.tar.xz" -C "$WORK_DIR"
CGAL_DIR="$WORK_DIR/CGAL-${CGAL_VERSION}"

echo "=== Downloading Boost ${BOOST_VERSION} ==="
download_with_retry "$WORK_DIR/boost.tar.gz" "${BOOST_URLS[@]}"
tar xf "$WORK_DIR/boost.tar.gz" -C "$WORK_DIR"
BOOST_ROOT="$WORK_DIR/boost_${BOOST_VERSION_UNDERSCORE}"

# =============================================================================
# Patch SFCGAL source
# =============================================================================

# SFCGAL's CMakeLists.txt line 92 hard-codes set(Boost_USE_STATIC_LIBS OFF),
# which overrides our -DBoost_USE_STATIC_LIBS=ON cache variable. Remove it
# so the option() on line 99 respects the cache.
sed -i.bak 's/^set(Boost_USE_STATIC_LIBS OFF)/#set(Boost_USE_STATIC_LIBS OFF)  # patched for iOS static build/' \
    "$SFCGAL_SRC/CMakeLists.txt"

# Debug: inject a diagnostic message into src/CMakeLists.txt so we can see
# exactly which sources GLOB_RECURSE picks up during cross-compilation.
sed -i.bak2 '/^file( GLOB_RECURSE SFCGAL_SOURCES/a\
message(STATUS "SFCGAL_SOURCES (glob result): ${SFCGAL_SOURCES}")
' "$SFCGAL_SRC/src/CMakeLists.txt"

# Debug: check how SFCGAL_API is defined (visibility issue?)
echo "=== Checking SFCGAL_API / export macro ==="
grep -n "SFCGAL_API\|visibility\|SFCGAL_BUILD_SHARED\|SFCGAL_USE_STATIC" "$SFCGAL_SRC/src/export.h" || echo "  export.h not found at expected path"
echo "=== Checking if Sphere.h uses SFCGAL_API ==="
head -30 "$SFCGAL_SRC/src/primitive3d/Sphere.h" 2>/dev/null || echo "  Sphere.h not found"

# =============================================================================
# Build required Boost libraries for iOS
# =============================================================================
# SFCGAL needs Boost.Thread, Boost.System, and Boost.Serialization (compiled).
# We build them with b2, which also generates native CMake config files.

echo "=== Bootstrapping Boost b2 ==="
(cd "$BOOST_ROOT" && ./bootstrap.sh --with-libraries=thread,system,serialization > /dev/null 2>&1)

# Build Boost for a single iOS target using b2
# Arguments: $1=sdk_name $2=arch $3=target_triple $4=variant_name
build_boost() {
    local sdk_name="$1"
    local arch="$2"
    local target_triple="$3"
    local variant_name="$4"

    local sdk_path
    sdk_path=$(xcrun --sdk "$sdk_name" --show-sdk-path)
    local cxx
    cxx=$(xcrun --sdk "$sdk_name" --find clang++)

    local boost_install="$WORK_DIR/boost-${variant_name}"

    echo "=== Building Boost for ${sdk_name} ${arch} ===" >&2

    local jam_file="$WORK_DIR/user-config-${variant_name}.jam"
    cat > "$jam_file" << JAMEOF
using clang : ios
    : ${cxx}
    : <compileflags>"-arch ${arch} -isysroot ${sdk_path} -target ${target_triple} -std=c++17 -DBOOST_AC_USE_PTHREADS -DBOOST_SP_USE_PTHREADS"
      <linkflags>"-arch ${arch} -isysroot ${sdk_path} -target ${target_triple}"
    ;
JAMEOF

    (
        cd "$BOOST_ROOT"
        ./b2 \
            --user-config="$jam_file" \
            --prefix="$boost_install" \
            --with-thread \
            --with-system \
            --with-serialization \
            toolset=clang-ios \
            link=static \
            threading=multi \
            variant=release \
            target-os=iphone \
            architecture=arm \
            -j"$NCPU" \
            install \
            > /dev/null 2>&1
    )

    echo "$boost_install"
}

BOOST_IOS_ARM64=$(build_boost iphoneos arm64 "arm64-apple-ios${IOS_MIN_VERSION}" ios-arm64)
BOOST_SIM_ARM64=$(build_boost iphonesimulator arm64 "arm64-apple-ios${IOS_MIN_VERSION}-simulator" simulator-arm64)
BOOST_SIM_X86=$(build_boost iphonesimulator x86_64 "x86_64-apple-ios${IOS_MIN_VERSION}-simulator" simulator-x86_64)

# =============================================================================
# Generate CMake toolchain file
# =============================================================================

generate_toolchain() {
    local sdk_name="$1"
    local arch="$2"
    local target_triple="$3"
    local toolchain_file="$4"

    local sdk_path
    sdk_path=$(xcrun --sdk "$sdk_name" --show-sdk-path)
    local cc
    cc=$(xcrun --sdk "$sdk_name" --find clang)
    local cxx
    cxx=$(xcrun --sdk "$sdk_name" --find clang++)

    cat > "$toolchain_file" << TCEOF
# Auto-generated iOS toolchain for ${sdk_name} ${arch}
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_OSX_ARCHITECTURES ${arch})
set(CMAKE_OSX_DEPLOYMENT_TARGET ${IOS_MIN_VERSION})
set(CMAKE_OSX_SYSROOT ${sdk_path})

set(CMAKE_C_COMPILER ${cc})
set(CMAKE_CXX_COMPILER ${cxx})

# Skip compiler checks — cross-compiling, can't run test binaries
set(CMAKE_C_COMPILER_WORKS TRUE)
set(CMAKE_CXX_COMPILER_WORKS TRUE)

set(CMAKE_C_FLAGS_INIT "-arch ${arch} -target ${target_triple}")
set(CMAKE_CXX_FLAGS_INIT "-arch ${arch} -target ${target_triple}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-arch ${arch} -target ${target_triple}")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
# BOTH allows CMake to find our cross-compiled packages outside the sysroot
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
TCEOF
}

# =============================================================================
# Build SFCGAL for a single target
# =============================================================================
# Arguments: $1=sdk_name $2=arch $3=target_triple $4=install_prefix
#            $5=gmp_prefix $6=mpfr_prefix $7=boost_prefix
build_sfcgal() {
    local sdk_name="$1"
    local arch="$2"
    local target_triple="$3"
    local prefix="$4"
    local gmp_prefix="$5"
    local mpfr_prefix="$6"
    local boost_prefix="$7"

    local build_dir="$WORK_DIR/build-${sdk_name}-${arch}"
    mkdir -p "$build_dir"

    local toolchain_file="$build_dir/ios-toolchain.cmake"
    generate_toolchain "$sdk_name" "$arch" "$target_triple" "$toolchain_file"

    echo "=== Configuring SFCGAL for ${sdk_name} ${arch} ==="
    cmake -S "$SFCGAL_SRC" -B "$build_dir" \
        -DCMAKE_TOOLCHAIN_FILE="$toolchain_file" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$prefix" \
        -DBUILD_SHARED_LIBS=OFF \
        -DSFCGAL_USE_STATIC_LIBS=ON \
        -DSFCGAL_BUILD_TESTS=OFF \
        -DSFCGAL_BUILD_EXAMPLES=OFF \
        -DSFCGAL_BUILD_BENCH=OFF \
        -DCGAL_DIR="$CGAL_DIR/lib/cmake/CGAL" \
        -DCMAKE_PREFIX_PATH="$boost_prefix" \
        -DBoost_USE_STATIC_LIBS=ON \
        -DCGAL_Boost_USE_STATIC_LIBS=ON \
        -DBoost_NO_SYSTEM_PATHS=ON \
        -DGMP_INCLUDE_DIR="$gmp_prefix/include" \
        -DGMP_LIBRARIES="$gmp_prefix/lib/libgmp.a" \
        -DMPFR_INCLUDE_DIR="$mpfr_prefix/include" \
        -DMPFR_LIBRARIES="$mpfr_prefix/lib/libmpfr.a" \
        -DCMAKE_CXX_STANDARD=17 \
        -Wno-dev \
        2>&1 | grep -E "(SFCGAL_SOURCES|primitive3d|Sphere|Cylinder|STATUS)" || true

    echo "=== Building SFCGAL for ${sdk_name} ${arch} ==="
    cmake --build "$build_dir" --config Release -j"$NCPU" 2>&1 | tail -5

    echo "=== Checking libSFCGAL.a contents for ${sdk_name} ${arch} ==="
    local lib_a
    lib_a=$(find "$build_dir" -name "libSFCGAL.a" | head -1)
    if [ -n "$lib_a" ]; then
        echo "  Archive: $lib_a"

        # Extract Sphere.cpp.o and dump ALL its symbols
        local extract_dir="$build_dir/nm-debug"
        mkdir -p "$extract_dir"
        (cd "$extract_dir" && ar x "$lib_a" Sphere.cpp.o 2>/dev/null) || true

        if [ -f "$extract_dir/Sphere.cpp.o" ]; then
            echo "  --- ALL defined symbols (T/t) in Sphere.cpp.o ---"
            nm "$extract_dir/Sphere.cpp.o" 2>/dev/null | grep -E " [Tt] " | head -20 || echo "  (none)"

            echo "  --- ALL undefined symbols (U) in Sphere.cpp.o ---"
            nm "$extract_dir/Sphere.cpp.o" 2>/dev/null | grep " U " | grep -i "sfcgal\|sphere\|cylinder" | head -10 || echo "  (none matching SFCGAL/Sphere/Cylinder)"

            echo "  --- Looking for ANY SFCGAL:: symbols in Sphere.cpp.o ---"
            nm "$extract_dir/Sphere.cpp.o" 2>/dev/null | grep "SFCGAL" | head -20 || echo "  NO SFCGAL symbols at all in Sphere.cpp.o"

            echo "  --- File size of Sphere.cpp.o ---"
            ls -la "$extract_dir/Sphere.cpp.o"
        else
            echo "  WARNING: Could not extract Sphere.cpp.o from archive"
        fi

        # Also check what buffer3D.cpp.o expects
        (cd "$extract_dir" && ar x "$lib_a" buffer3D.cpp.o 2>/dev/null) || true
        if [ -f "$extract_dir/buffer3D.cpp.o" ]; then
            echo "  --- Undefined SFCGAL::Sphere/Cylinder symbols needed by buffer3D.cpp.o ---"
            nm "$extract_dir/buffer3D.cpp.o" 2>/dev/null | grep " U " | grep -iE "sphere|cylinder" | head -10 || echo "  (none)"
        fi

        # Check the CMake compile command for Sphere.cpp
        echo "  --- CMake compile command for Sphere.cpp ---"
        find "$build_dir" -name "*.make" -o -name "compile_commands.json" | head -3
        grep -r "Sphere.cpp" "$build_dir/src/CMakeFiles/SFCGAL.dir/flags.make" 2>/dev/null || true
        grep "Sphere.cpp" "$build_dir/compile_commands.json" 2>/dev/null | head -5 || true
    else
        echo "  WARNING: libSFCGAL.a not found in build dir"
    fi

    echo "=== Installing SFCGAL for ${sdk_name} ${arch} ==="
    cmake --install "$build_dir" > /dev/null 2>&1
}

mkdir -p "$OUTPUT_DIR"

# 1. iOS device (arm64)
build_sfcgal \
    iphoneos \
    arm64 \
    "arm64-apple-ios${IOS_MIN_VERSION}" \
    "$OUTPUT_DIR/ios-arm64" \
    "$GMP_DIR/ios-arm64" \
    "$MPFR_DIR/ios-arm64" \
    "$BOOST_IOS_ARM64"

# 2. iOS Simulator (arm64, Apple Silicon)
build_sfcgal \
    iphonesimulator \
    arm64 \
    "arm64-apple-ios${IOS_MIN_VERSION}-simulator" \
    "$OUTPUT_DIR/simulator-arm64" \
    "$GMP_DIR/simulator-arm64" \
    "$MPFR_DIR/simulator-arm64" \
    "$BOOST_SIM_ARM64"

# 3. iOS Simulator (x86_64, Intel)
build_sfcgal \
    iphonesimulator \
    x86_64 \
    "x86_64-apple-ios${IOS_MIN_VERSION}-simulator" \
    "$OUTPUT_DIR/simulator-x86_64" \
    "$GMP_DIR/simulator-x86_64" \
    "$MPFR_DIR/simulator-x86_64" \
    "$BOOST_SIM_X86"

# =============================================================================
# Create fat simulator library
# =============================================================================

echo "=== Creating fat simulator library ==="
mkdir -p "$OUTPUT_DIR/simulator-fat/lib"
cp -R "$OUTPUT_DIR/simulator-arm64/include" "$OUTPUT_DIR/simulator-fat/include"
lipo -create \
    "$OUTPUT_DIR/simulator-arm64/lib/libSFCGAL.a" \
    "$OUTPUT_DIR/simulator-x86_64/lib/libSFCGAL.a" \
    -output "$OUTPUT_DIR/simulator-fat/lib/libSFCGAL.a"

# =============================================================================
# Verify all outputs
# =============================================================================

echo ""
echo "=== Verification ==="
verify_lib() {
    local lib="$1"
    local expected_platform="$2"
    local label="$3"

    local arch
    arch=$(lipo -info "$lib" 2>&1)
    local platform
    platform=$(otool -l "$lib" 2>&1 | grep -A2 LC_BUILD_VERSION | grep platform | head -1 | awk '{print $2}')

    local status="OK"
    if [ "$platform" != "$expected_platform" ]; then
        status="FAIL (expected platform $expected_platform, got $platform)"
    fi

    echo "  ${label}: ${arch} | platform=${platform} | ${status}"
}

# platform 2 = IOS, platform 7 = IOS_SIMULATOR
verify_lib "$OUTPUT_DIR/ios-arm64/lib/libSFCGAL.a" "2" "iOS device arm64"
verify_lib "$OUTPUT_DIR/simulator-arm64/lib/libSFCGAL.a" "7" "Simulator arm64"
verify_lib "$OUTPUT_DIR/simulator-x86_64/lib/libSFCGAL.a" "7" "Simulator x86_64"

echo "  Simulator fat: $(lipo -info "$OUTPUT_DIR/simulator-fat/lib/libSFCGAL.a")"

# Verify C API header is present
echo ""
echo "=== C API header check ==="
if [ -f "$OUTPUT_DIR/ios-arm64/include/SFCGAL/capi/sfcgal_c.h" ]; then
    echo "  sfcgal_c.h: OK"
else
    echo "  sfcgal_c.h: MISSING"
    echo "  Searching for sfcgal_c.h..."
    find "$OUTPUT_DIR/ios-arm64/include" -name "sfcgal_c.h" 2>/dev/null || echo "  Not found in install prefix"
fi

# =============================================================================
# Link test
# =============================================================================

echo ""
echo "=== Link test ==="
TEST_DIR="$WORK_DIR/link-test"
mkdir -p "$TEST_DIR"

cat > "$TEST_DIR/test_sfcgal.c" << 'CEOF'
#include <SFCGAL/capi/sfcgal_c.h>
#include <stdio.h>

int main(void) {
    sfcgal_init();
    const char* version = sfcgal_version();
    printf("SFCGAL %s linked OK\n", version);
    return 0;
}
CEOF

IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_CXX=$(xcrun --sdk iphoneos --find clang++)

# SFCGAL is C++, link with clang++ and all static dependencies
"$IOS_CXX" \
    -arch arm64 \
    -isysroot "$IOS_SDK" \
    -target "arm64-apple-ios${IOS_MIN_VERSION}" \
    -I"$OUTPUT_DIR/ios-arm64/include" \
    -I"$GMP_DIR/ios-arm64/include" \
    -I"$MPFR_DIR/ios-arm64/include" \
    -L"$OUTPUT_DIR/ios-arm64/lib" \
    -L"$GMP_DIR/ios-arm64/lib" \
    -L"$MPFR_DIR/ios-arm64/lib" \
    -L"$BOOST_IOS_ARM64/lib" \
    -lSFCGAL -lboost_serialization -lboost_thread -lboost_system \
    -lmpfr -lgmp -lc++ \
    -o "$TEST_DIR/test_sfcgal" \
    "$TEST_DIR/test_sfcgal.c" \
    2>&1

if [ $? -eq 0 ]; then
    echo "  Link test: OK"
    file "$TEST_DIR/test_sfcgal"
else
    echo "  Link test: FAIL"
    exit 1
fi

echo ""
echo "=== Build complete ==="
echo "Output: $OUTPUT_DIR"
echo ""
echo "Directory structure:"
find "$OUTPUT_DIR" -name "*.a" -o -name "sfcgal_c.h" | sort
