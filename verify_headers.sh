#!/bin/bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <glibc-version> <headers-dir> <kernel-headers-dir> <output-dir>" >&2
    exit 1
fi

VERSION=$1
HEADERS_DIR=$2
KERNEL_HEADERS_DIR=$3
OUTPUT_DIR=$4
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RESOURCE_DIR=$(clang-20 -print-resource-dir)
COUNT=0
mkdir -p "$OUTPUT_DIR"

for target_dir in "$HEADERS_DIR"/*; do
    [[ -d "$target_dir/include" ]] || continue
    target=$(basename "$target_dir")
    case "$target" in
        arm-*|armeb-*) arch=arm ;;
        aarch64*) arch=arm64 ;;
        loongarch*) arch=loongarch ;;
        m68k-*) arch=m68k ;;
        mips*) arch=mips ;;
        powerpc*) arch=powerpc ;;
        riscv*) arch=riscv ;;
        s390*) arch=s390 ;;
        sparc*) arch=sparc ;;
        i686-*|x86_64-*) arch=x86 ;;
        *) echo "Unknown target: $target" >&2; exit 1 ;;
    esac
    test -d "$KERNEL_HEADERS_DIR/$arch/include"
    FLAGS=(-target "$target" -nostdinc
        -isystem "$RESOURCE_DIR/include" -isystem "$target_dir/include"
        -isystem "$KERNEL_HEADERS_DIR/$arch/include"
        -DEXPECTED_GLIBC_MINOR="${VERSION#2.}" -D_GNU_SOURCE
        -D_FILE_OFFSET_BITS=64 -D_FORTIFY_SOURCE=2 -O2 -Wall -Werror)
    if [[ "$target" == loongarch64* ]]; then
        FLAGS+=(-mabi=lp64d)
    fi
    if [[ "$target" == m68k-* ]]; then
        # Clang rejects the GNU floating-point register constraints in old math.h.
        FLAGS+=(-D__NO_MATH_INLINES)
    fi
    if [[ "$target" == sparc-linux-gnu ]]; then
        # Old stdio/wchar inlines use functions before their asm-name declarations.
        FLAGS+=(-O0 -U_FORTIFY_SOURCE)
    fi

    clang-20 "${FLAGS[@]}" -std=gnu11 -c "$SCRIPT_DIR/tests/headers.c" -o "$OUTPUT_DIR/$target.c.o"
    clang++-20 "${FLAGS[@]}" -std=c++11 -D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS \
        -D__STDC_FORMAT_MACROS -x c++ -c "$SCRIPT_DIR/tests/headers.c" -o "$OUTPUT_DIR/$target.cxx.o"
    clang-20 "${FLAGS[@]}" -std=gnu11 -c "$SCRIPT_DIR/tests/syscall.c" -o "$OUTPUT_DIR/$target.syscall.c.o"
    clang++-20 "${FLAGS[@]}" -std=c++11 -x c++ -c "$SCRIPT_DIR/tests/syscall.c" -o "$OUTPUT_DIR/$target.syscall.cxx.o"
    readelf -h "$OUTPUT_DIR/$target.c.o" "$OUTPUT_DIR/$target.cxx.o" > "$OUTPUT_DIR/$target.elf.txt"

    case "$target" in
        arm-linux-gnueabihf|armeb-linux-gnueabihf) loader=ld-linux-armhf.so.3 ;;
        arm-linux-gnueabi|armeb-linux-gnueabi) loader=ld-linux.so.3 ;;
        x86_64-linux-gnux32) loader=ld-linux-x32.so.2 ;;
        *) loader= ;;
    esac
    if [[ -n "$loader" ]]; then
        actual_loader=$(printf '#include <gnu/lib-names.h>\nLD_SO\n' | \
            clang-20 "${FLAGS[@]}" -E -P -x c - | tail -n 1)
        if [[ "$actual_loader" != "\"$loader\"" ]]; then
            echo "Wrong loader for $target: $actual_loader (expected $loader)" >&2
            exit 1
        fi
    fi
    echo "Verified $VERSION $target (C, C++, ELF header)"
    COUNT=$((COUNT + 1))
done

if [[ "$COUNT" -eq 0 ]]; then
    echo "No headers found in $HEADERS_DIR" >&2
    exit 1
fi
