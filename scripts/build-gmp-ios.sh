#!/usr/bin/env bash
#
# build-gmp-ios.sh — Cross-compile GMP 6.3.0 for iOS device and simulator
#
# Produces:
#   $OUTPUT_DIR/ios-arm64/          — device (arm64, platform IOS)
#   $OUTPUT_DIR/simulator-arm64/    — simulator Apple Silicon (arm64, platform IOS_SIMULATOR)
#   $OUTPUT_DIR/simulator-x86_64/   — simulator Intel (x86_64, platform IOS_SIMULATOR)
#   $OUTPUT_DIR/simulator-fat/      — merged simulator (arm64 + x86_64)
#
# Usage:
#   ./scripts/build-gmp-ios.sh [output_dir]
#
# Requirements:
#   - Xcode (not just Command Line Tools) for iOS SDKs
#   - curl, tar, lipo, otool

set -euo pipefail

GMP_VERSION="${GMP_VERSION_OVERRIDE:-6.3.0}"
GMP_URLS=(
    "https://gmplib.org/download/gmp/gmp-${GMP_VERSION}.tar.xz"
    "https://ftp.gnu.org/gnu/gmp/gmp-${GMP_VERSION}.tar.xz"
)
IOS_MIN_VERSION="15.0"

OUTPUT_DIR="$(cd "$(dirname "${1:-$(pwd)/gmp-ios-build}")" && pwd)/$(basename "${1:-$(pwd)/gmp-ios-build}")"
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

echo "=== Downloading GMP ${GMP_VERSION} ==="
download_with_retry "$WORK_DIR/gmp.tar.xz" "${GMP_URLS[@]}"
tar xf "$WORK_DIR/gmp.tar.xz" -C "$WORK_DIR"
GMP_SRC="$WORK_DIR/gmp-${GMP_VERSION}"

# Build GMP for a single target
# Arguments: $1=sdk_name $2=arch $3=target_triple $4=host_triplet $5=install_prefix
build_gmp() {
    local sdk_name="$1"
    local arch="$2"
    local target_triple="$3"
    local host_triplet="$4"
    local prefix="$5"

    local sdk_path
    sdk_path=$(xcrun --sdk "$sdk_name" --show-sdk-path)
    local cc
    cc=$(xcrun --sdk "$sdk_name" --find clang)
    local cxx
    cxx=$(xcrun --sdk "$sdk_name" --find clang++)

    local cflags="-arch ${arch} -isysroot ${sdk_path} -target ${target_triple} -O2"
    local ldflags="-arch ${arch} -isysroot ${sdk_path} -target ${target_triple}"

    local build_dir="$WORK_DIR/build-${sdk_name}-${arch}"
    mkdir -p "$build_dir"

    echo "=== Configuring GMP for ${sdk_name} ${arch} ==="
    (
        cd "$build_dir"
        "$GMP_SRC/configure" \
            --host="$host_triplet" \
            --disable-assembly \
            --enable-static \
            --disable-shared \
            --prefix="$prefix" \
            CC="$cc" \
            CXX="$cxx" \
            CFLAGS="$cflags" \
            CXXFLAGS="$cflags" \
            LDFLAGS="$ldflags" \
            > /dev/null 2>&1
    )

    echo "=== Building GMP for ${sdk_name} ${arch} ==="
    make -C "$build_dir" -j"$NCPU" > /dev/null 2>&1

    echo "=== Installing GMP for ${sdk_name} ${arch} ==="
    make -C "$build_dir" install > /dev/null 2>&1
}

mkdir -p "$OUTPUT_DIR"

# 1. iOS device (arm64)
build_gmp \
    iphoneos \
    arm64 \
    "arm64-apple-ios${IOS_MIN_VERSION}" \
    aarch64-apple-darwin \
    "$OUTPUT_DIR/ios-arm64"

# 2. iOS Simulator (arm64, Apple Silicon)
build_gmp \
    iphonesimulator \
    arm64 \
    "arm64-apple-ios${IOS_MIN_VERSION}-simulator" \
    aarch64-apple-darwin \
    "$OUTPUT_DIR/simulator-arm64"

# 3. iOS Simulator (x86_64, Intel)
build_gmp \
    iphonesimulator \
    x86_64 \
    "x86_64-apple-ios${IOS_MIN_VERSION}-simulator" \
    x86_64-apple-darwin \
    "$OUTPUT_DIR/simulator-x86_64"

# 4. Create fat simulator library
echo "=== Creating fat simulator library ==="
mkdir -p "$OUTPUT_DIR/simulator-fat/lib"
cp -R "$OUTPUT_DIR/simulator-arm64/include" "$OUTPUT_DIR/simulator-fat/include"
lipo -create \
    "$OUTPUT_DIR/simulator-arm64/lib/libgmp.a" \
    "$OUTPUT_DIR/simulator-x86_64/lib/libgmp.a" \
    -output "$OUTPUT_DIR/simulator-fat/lib/libgmp.a"

# 5. Verify all outputs
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
verify_lib "$OUTPUT_DIR/ios-arm64/lib/libgmp.a" "2" "iOS device arm64"
verify_lib "$OUTPUT_DIR/simulator-arm64/lib/libgmp.a" "7" "Simulator arm64"
verify_lib "$OUTPUT_DIR/simulator-x86_64/lib/libgmp.a" "7" "Simulator x86_64"

echo "  Simulator fat: $(lipo -info "$OUTPUT_DIR/simulator-fat/lib/libgmp.a")"

echo ""
echo "=== Build complete ==="
echo "Output: $OUTPUT_DIR"
echo ""
echo "Directory structure:"
find "$OUTPUT_DIR" -name "*.a" -o -name "*.h" | sort | head -20
