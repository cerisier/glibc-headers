# GNU C Library Headers

This project generates vanilla GNU C Library headers:

1. For glibc 2.17 and newer
2. For a fixed set of targets, where supported by each glibc release

Upstream is from the `release/2.x/master` branch of the glibc git which includes security patches.

## Build inputs

`glibc_versions.txt` lists supported glibc releases. `Dockerfile` pins one recent Linux kernel header version for all releases, with separate headers for each target architecture. Kernel downloads are cached across glibc versions.

A matching kernel version per glibc release is unnecessary; [upstream recommends recent Linux headers](https://sourceware.org/glibc/manual/latest/html_node/Linux.html). For glibc 2.17-2.26, the selected kernel headers determine the generated `SYS_*` syscall aliases. From glibc 2.27, these aliases come from glibc's own syscall list.

To add a glibc release, append its version to `glibc_versions.txt`. Update the shared `KERNEL_VERSION` pin independently when needed. Builds use Clang's target compiler and preprocessor; host tools use the host compiler.

## Build and publish

Build explicit versions with Docker:

```sh
bash build_all.sh 2.17 2.27
```

Outputs are written to `headers/<version>`. Existing output directories are rejected. With no arguments, `build_all.sh` and `archive.sh` select versions added in the unstaged diff of `glibc_versions.txt`; use explicit versions after committing that file or when refreshing the kernel pin.

From a separate publishing checkout containing the generated `headers/<version>` directories:

```sh
bash archive.sh 2.17 2.27
bash pages.sh
```

`archive.sh` creates and pushes date-stamped tags, then uploads aggregate and per-target archives with `sha256sums.txt`. Its `--local` option creates archives without publishing; use a fresh archive directory to avoid collisions with existing files.

`pages.sh` regenerates the release pages and JSON index, switches to `gh-pages`, replaces its tracked files, and force-pushes that branch. Run it in the publishing checkout so the development checkout and local build outputs stay in place.

## ⚠️ Limitations

1. Use of `clang -target` instead of GCC cross-compilers.
2. Empty `gnu/stubs.h`.

First, the process relies on invoking `clang -target` as a cross-compiler, when internally invoked by `make install-headers`. While this works in practice, it may lead to subtle discrepancies, as Clang’s internal expansion of -target to cc1 options may not fully replicate the behavior of carefully tuned GCC cross-compilers (e.g., using --with-cpu, -mabi, etc.). I have manually verified several headers produced by both approaches, and they were identical so far.

Secondly, `gnu/stubs.h` normally contains defines used by autoconf or manually to detect whether a symbol exposed by glibc is a stub. That information requires a full library build; this project installs an empty placeholder.

Generation uses `make install-headers`; no glibc libraries are built or linked. With explicit target kernel headers, `verify_headers.sh` checks C/C++ compilation, target ABI assertions, and loader selection, and records ELF headers for inspection.

Clang rejects some old m68k math inlines and optimized SPARC32 stdio/wchar inlines. Verification uses glibc's `__NO_MATH_INLINES` switch for m68k and `-O0` without fortification for SPARC32. The generated headers remain unchanged.

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
* powerpc64le-linux-gnu # glibc >= 2.19
* riscv32-linux-gnu # glibc >= 2.32
* riscv64-linux-gnu # glibc >= 2.27
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

Published releases contain aggregate and per-target header archives in gzip and Zstandard formats, with SHA256 checksums.

Visit https://cerisier.github.io/glibc-headers/
