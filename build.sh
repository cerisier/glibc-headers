#!/bin/bash
set -e

SCRIPT_DIR=$(dirname "$0")
KERNEL_HEADERS_BASE_DIR=${KERNEL_HEADERS_BASE_DIR:-"/dev/null"}

GLIBC_VERSION=${1:-"2.38"}
KERNEL_VERSION=$(awk -v version="$GLIBC_VERSION" '$1 == version { print $2 }' "$SCRIPT_DIR/glibc_kernel_versions.txt")

SRC_DIR=$(pwd)
BUILD_ROOT=$(pwd)/build/$GLIBC_VERSION
OUTPUT_ROOT=$(pwd)/headers/$GLIBC_VERSION

function process_target() {
  TARGET=$1
  KERNEL_ARCH=$2

  if [[ -n "${TARGETS:-}" && " ${TARGETS} " != *" ${TARGET} "* ]]; then
    return
  fi

  cd "${SRC_DIR}"

  CC="clang-20 -fgnuc-version=13"
  CXX="clang++-20 -fgnuc-version=13"
  CROSS_CC="${CC} -target ${TARGET} -B/usr/local/bin -fuse-ld=lld"
  CROSS_CXX="${CXX} -target ${TARGET} -B/usr/local/bin -fuse-ld=lld"

  # CC="$(pwd)/gcc-13.2.0-nolibc/aarch64-linux/bin/aarch64-linux-gcc"
  # CXX="$(pwd)/gcc-13.2.0-nolibc/aarch64-linux/bin/aarch64-linux-g++"
  # CROSS_CC="${CC}"
  # CROSS_CXX="${CXX}"

  echo "=============================="
  echo "Processing target: $TARGET"
  echo "=============================="

  # Create build and output directories
  BUILD_DIR="${BUILD_ROOT}/${TARGET}"
  OUTPUT_DIR="${OUTPUT_ROOT}/${TARGET}"
  mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

  if [[ -f "${OUTPUT_DIR}/include/gnu/stubs.h" ]]; then
    echo "Headers already installed for ${TARGET}, skipping..."
    return
  fi

  cd "${BUILD_DIR}"

  echo "Configuring glibc for ${TARGET}..."

  EXTRA_FLAGS=""
  if [[ "${TARGET}" == aarch64* ]]; then
    EXTRA_FLAGS="--disable-mathvec"
  elif [[ "${TARGET}" == "loongarch64"* ]]; then
    EXTRA_FLAGS="CFLAGS=-mabi=lp64d CXXFLAGS=-mabi=lp64d"
  fi

  cat > config.cache <<EOF
libc_cv_pde_load_address=yes
libc_cv_ctors_header=yes=yes
libc_cv_visibility_attribute=yes
libc_cv_broken_visibility_attribute=no
libc_cv_broken_alias_attribute=no
libc_cv_initfini_array=yes
libc_cv_ld_no_whole_archive=yes
libc_cv_gcc_tls_model_attr=yes
libc_cv_forced_unwind=yes
libc_cv_c_cleanup=yes
EOF
  if [[ $(echo "$GLIBC_VERSION < 2.28" | bc) -eq 1 ]]; then
    # The old PowerPC relocation probe is irrelevant to install-headers.
    echo "libc_cv_ppc_rel16=yes" >> config.cache
  fi

  "${SRC_DIR}/configure" \
    --host="${TARGET}" \
    --prefix="${OUTPUT_DIR}" \
  	--cache-file=config.cache \
    --disable-werror \
    --with-headers=$KERNEL_HEADERS_BASE_DIR/$KERNEL_ARCH/include \
    $EXTRA_FLAGS \
    CC="${CROSS_CC}" \
    CXX="${CROSS_CXX}" \
    LD=/usr/local/bin/ld \
    CPP="${CROSS_CC} -E" \
    CXXCPP="${CROSS_CXX} -E"

  echo "Installing headers for ${TARGET}..."
  MAKE_FLAGS=()
  if [[ "$TARGET" == x86_64-linux-gnux32 && $(echo "$GLIBC_VERSION >= 2.19 && $GLIBC_VERSION < 2.28" | bc) -eq 1 ]]; then
    # The old x32 syscall generator needs echo to preserve literal backslashes.
    MAKE_FLAGS+=(SHELL=/bin/bash)
  fi
  if [[ $(echo "$GLIBC_VERSION >= 2.24 && $GLIBC_VERSION < 2.28" | bc) -eq 1 ]]; then
    # C++ test-header copies require a cross C++ library, unused by install-headers.
    MAKE_FLAGS+=(CXX=)
  fi
  make CC="${CROSS_CC}" CXX="${CROSS_CXX}" ARCH=${KERNEL_ARCH} BUILD_CC="${HOST_CC:-clang-20}" "${MAKE_FLAGS[@]}" cross-compiling=yes install-headers

  touch "${OUTPUT_DIR}/include/gnu/stubs.h"
  touch "${OUTPUT_DIR}/include/bits/stdio_lim.h"

  echo "Headers installed in ${OUTPUT_DIR}"
}
 
# clang has no support for ARC by default
# process_target "arc-linux-gnu"              arc

process_target "arm-linux-gnueabi"          arm
process_target "arm-linux-gnueabihf"        arm
process_target "armeb-linux-gnueabi"        arm
process_target "armeb-linux-gnueabihf"      arm
process_target "aarch64-linux-gnu"          arm64
process_target "aarch64_be-linux-gnu"       arm64  

# loongarch64 is only supported in glibc >= 2.35
if [[ $(echo "$GLIBC_VERSION >= 2.35" | bc) -eq 1 ]]; then
    process_target "loongarch64-linux-gnu"      loongarch
fi

process_target "m68k-linux-gnu"             m68k
process_target "mips-linux-gnueabi"         mips
process_target "mips-linux-gnueabihf"       mips
process_target "mipsel-linux-gnueabi"       mips
process_target "mipsel-linux-gnueabihf"     mips
process_target "mips64-linux-gnuabi64"      mips
process_target "mips64-linux-gnuabin32"     mips
process_target "mips64el-linux-gnuabi64"    mips
process_target "mips64el-linux-gnuabin32"   mips
process_target "powerpc-linux-gnueabi"      powerpc
process_target "powerpc-linux-gnueabihf"    powerpc
process_target "powerpc64-linux-gnu"        powerpc
if [[ $(echo "$GLIBC_VERSION >= 2.19" | bc) -eq 1 ]]; then
    process_target "powerpc64le-linux-gnu"      powerpc
fi

# risvc32 is only supported in glibc >= 2.32
if [[ $(echo "$GLIBC_VERSION >= 2.32" | bc) -eq 1 ]]; then
    process_target "riscv32-linux-gnu"          riscv # glibc >= 2.32
fi

if [[ $(echo "$GLIBC_VERSION >= 2.27" | bc) -eq 1 ]]; then
    process_target "riscv64-linux-gnu"          riscv
fi
process_target "s390x-linux-gnu"            s390
process_target "sparc-linux-gnu"            sparc
process_target "sparc64-linux-gnu"          sparc
process_target "i686-linux-gnu"             x86
process_target "x86_64-linux-gnu"           x86
process_target "x86_64-linux-gnux32"        x86

echo "✅ Done generating headers for all targets."
