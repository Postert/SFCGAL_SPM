#!/usr/bin/env bash
#
# build-mpfr-ios.sh — Cross-compile MPFR 4.2.1 for iOS device and simulator
#
# Produces:
#   $OUTPUT_DIR/ios-arm64/          — device (arm64, platform IOS)
#   $OUTPUT_DIR/simulator-arm64/    — simulator Apple Silicon (arm64, platform IOS_SIMULATOR)
#   $OUTPUT_DIR/simulator-x86_64/   — simulator Intel (x86_64, platform IOS_SIMULATOR)
#   $OUTPUT_DIR/simulator-fat/      — merged simulator (arm64 + x86_64)
#
# Usage:
#   ./scripts/build-mpfr-ios.sh <gmp_dir> [output_dir]
#
#   gmp_dir:    path to GMP cross-compiled output (from build-gmp-ios.sh)
#   output_dir: where to place MPFR builds (default: ./mpfr-ios-build)
#
# Requirements:
#   - Xcode (not just Command Line Tools) for iOS SDKs
#   - Cross-compiled GMP (run build-gmp-ios.sh first)
#   - curl, tar, lipo, otool

set -euo pipefail

MPFR_VERSION="${MPFR_VERSION_OVERRIDE:-4.2.1}"
MPFR_URLS=(
    "https://www.mpfr.org/mpfr-${MPFR_VERSION}/mpfr-${MPFR_VERSION}.tar.xz"
    "https://ftp.gnu.org/gnu/mpfr/mpfr-${MPFR_VERSION}.tar.xz"
)
IOS_MIN_VERSION="15.0"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <gmp_dir> [output_dir]"
    echo "  gmp_dir:    path to GMP cross-compiled output (from build-gmp-ios.sh)"
    echo "  output_dir: where to place MPFR builds (default: ./mpfr-ios-build)"
    exit 1
fi

GMP_DIR="$(cd "$1" && pwd)"
OUTPUT_DIR="$(mkdir -p "${2:-$(pwd)/mpfr-ios-build}" && cd "${2:-$(pwd)/mpfr-ios-build}" && pwd)"
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

# Validate GMP builds exist
for variant in ios-arm64 simulator-arm64 simulator-x86_64; do
    if [ ! -f "$GMP_DIR/$variant/lib/libgmp.a" ]; then
        echo "ERROR: Missing GMP build at $GMP_DIR/$variant/lib/libgmp.a"
        echo "Run build-gmp-ios.sh first."
        exit 1
    fi
done

echo "=== Downloading MPFR ${MPFR_VERSION} ==="
download_with_retry "$WORK_DIR/mpfr.tar.xz" "${MPFR_URLS[@]}"
tar xf "$WORK_DIR/mpfr.tar.xz" -C "$WORK_DIR"
MPFR_SRC="$WORK_DIR/mpfr-${MPFR_VERSION}"

# Build MPFR for a single target
# Arguments: $1=sdk_name $2=arch $3=target_triple $4=host_triplet $5=install_prefix $6=gmp_prefix
build_mpfr() {
    local sdk_name="$1"
    local arch="$2"
    local target_triple="$3"
    local host_triplet="$4"
    local prefix="$5"
    local gmp_prefix="$6"

    local sdk_path
    sdk_path=$(xcrun --sdk "$sdk_name" --show-sdk-path)
    local cc
    cc=$(xcrun --sdk "$sdk_name" --find clang)

    local cflags="-arch ${arch} -isysroot ${sdk_path} -target ${target_triple} -O2"
    local ldflags="-arch ${arch} -isysroot ${sdk_path} -target ${target_triple}"

    local build_dir="$WORK_DIR/build-${sdk_name}-${arch}"
    mkdir -p "$build_dir"

    echo "=== Configuring MPFR for ${sdk_name} ${arch} ==="
    (
        cd "$build_dir"
        "$MPFR_SRC/configure" \
            --host="$host_triplet" \
            --enable-static \
            --disable-shared \
            --with-gmp="$gmp_prefix" \
            --prefix="$prefix" \
            CC="$cc" \
            CFLAGS="$cflags" \
            LDFLAGS="$ldflags" \
            > /dev/null 2>&1
    )

    echo "=== Building MPFR for ${sdk_name} ${arch} ==="
    make -C "$build_dir" -j"$NCPU" > /dev/null 2>&1

    echo "=== Installing MPFR for ${sdk_name} ${arch} ==="
    make -C "$build_dir" install > /dev/null 2>&1
}

mkdir -p "$OUTPUT_DIR"

# 1. iOS device (arm64)
build_mpfr \
    iphoneos \
    arm64 \
    "arm64-apple-ios${IOS_MIN_VERSION}" \
    aarch64-apple-darwin \
    "$OUTPUT_DIR/ios-arm64" \
    "$GMP_DIR/ios-arm64"

# 2. iOS Simulator (arm64, Apple Silicon)
build_mpfr \
    iphonesimulator \
    arm64 \
    "arm64-apple-ios${IOS_MIN_VERSION}-simulator" \
    aarch64-apple-darwin \
    "$OUTPUT_DIR/simulator-arm64" \
    "$GMP_DIR/simulator-arm64"

# 3. iOS Simulator (x86_64, Intel)
build_mpfr \
    iphonesimulator \
    x86_64 \
    "x86_64-apple-ios${IOS_MIN_VERSION}-simulator" \
    x86_64-apple-darwin \
    "$OUTPUT_DIR/simulator-x86_64" \
    "$GMP_DIR/simulator-x86_64"

# 4. Create fat simulator library
echo "=== Creating fat simulator library ==="
mkdir -p "$OUTPUT_DIR/simulator-fat/lib"
cp -R "$OUTPUT_DIR/simulator-arm64/include" "$OUTPUT_DIR/simulator-fat/include"
lipo -create \
    "$OUTPUT_DIR/simulator-arm64/lib/libmpfr.a" \
    "$OUTPUT_DIR/simulator-x86_64/lib/libmpfr.a" \
    -output "$OUTPUT_DIR/simulator-fat/lib/libmpfr.a"

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
verify_lib "$OUTPUT_DIR/ios-arm64/lib/libmpfr.a" "2" "iOS device arm64"
verify_lib "$OUTPUT_DIR/simulator-arm64/lib/libmpfr.a" "7" "Simulator arm64"
verify_lib "$OUTPUT_DIR/simulator-x86_64/lib/libmpfr.a" "7" "Simulator x86_64"

echo "  Simulator fat: $(lipo -info "$OUTPUT_DIR/simulator-fat/lib/libmpfr.a")"

# 6. Test linking with a minimal program
echo ""
echo "=== Link test ==="
TEST_DIR="$WORK_DIR/link-test"
mkdir -p "$TEST_DIR"

cat > "$TEST_DIR/test_mpfr.c" << 'CEOF'
#include <mpfr.h>
#include <stdio.h>

int main(void) {
    mpfr_t x;
    mpfr_init2(x, 256);
    mpfr_set_d(x, 3.14159, MPFR_RNDN);
    mpfr_clear(x);
    printf("MPFR %s linked OK\n", mpfr_get_version());
    return 0;
}
CEOF

IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_CC=$(xcrun --sdk iphoneos --find clang)

"$IOS_CC" \
    -arch arm64 \
    -isysroot "$IOS_SDK" \
    -target "arm64-apple-ios${IOS_MIN_VERSION}" \
    -I"$OUTPUT_DIR/ios-arm64/include" \
    -I"$GMP_DIR/ios-arm64/include" \
    -L"$OUTPUT_DIR/ios-arm64/lib" \
    -L"$GMP_DIR/ios-arm64/lib" \
    -lmpfr -lgmp \
    -o "$TEST_DIR/test_mpfr" \
    "$TEST_DIR/test_mpfr.c" \
    2>&1

if [ $? -eq 0 ]; then
    echo "  Link test: OK"
    file "$TEST_DIR/test_mpfr"
else
    echo "  Link test: FAIL"
    exit 1
fi

echo ""
echo "=== Build complete ==="
echo "Output: $OUTPUT_DIR"
echo ""
echo "Directory structure:"
find "$OUTPUT_DIR" -name "*.a" -o -name "*.h" | sort | head -20
