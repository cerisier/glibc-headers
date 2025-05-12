# GNU C Library Headers

This project generates and distributes vanilla GNU C Library Headers:
1. For every version of the glibC >= 2.28 
2. For a fixed set of targets

Upstream is from the `release/2.x/master` branch of the glibc git which includes security patches.

## ⚠️ Limitations

1. Use of `clang -target` instead of GCC cross-compilers.
2. Missing `stubs.h`.

First, the process relies on invoking `clang -target` as a cross-compiler, when internally invoked by `make install-headers`. While this works in practice, it may lead to subtle discrepancies, as Clang’s internal expansion of -target to cc1 options may not fully replicate the behavior of carefully tuned GCC cross-compilers (e.g., using --with-cpu, -mabi, etc.). I have manually verified several headers produced by both approaches, and they were identical so far.

Secondly, the full set of glibc headers includes a file named `stubs.h`, which contains defines used by autoconf or manually to detect if a symbol exposed by the glibc is a stub or not. This file is generated only as part of a full build. It is not currently included in the output.

Generating pristine C headers is in progress, but doing so requires building both glibc and a matching GCC toolchain for every target and version up to 2.28. This is a long and resource-intensive process, so for now, this best-effort approach provides a practical interim solution while I'm building them the right way.

## Distributed targets

* arm-linux-gnueabi
* arm-linux-gnueabihf
* armeb-linux-gnueabi
* armeb-linux-gnueabihf
* aarch64-linux-gnu
* aarch64_be-linux-gnu
* loongarch64-linux-gnu # For glibc >= 2.35
* m68k-linux-gnu
* mips-linux-gnueabi
* mips-linux-gnueabihf
* mipsel-linux-gnueabi
* mipsel-linux-gnueabihf
* mips64-linux-gnuabi64
* mips64-linux-gnuabin32
* mips64el-linux-gnuabi64
* mips64el-linux-gnuabin32
* powerpc-linux-gnueabi
* powerpc-linux-gnueabihf
* powerpc64-linux-gnu
* powerpc64le-linux-gnu
* riscv32-linux-gnu # glibc >= 2.32
* riscv64-linux-gnu
* s390x-linux-gnu
* sparc-linux-gnu
* sparc64-linux-gnu
* i686-linux-gnu
* x86_64-linux-gnu
* x86_64-linux-gnux32

# Notably missing targets

* arc-linux-gnu (ARC is experimental in clang)

The rest of missing targets were either too rare and specific to justify generating them or clang didn't come with support for the target cpu.

### Distributed Tarballs

This project distributes headers for all versions of the glibc >= 2.2.28.

Visit https://cerisier.github.io/glibc-headers/
