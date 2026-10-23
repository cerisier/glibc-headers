#!/bin/bash

if [ -f "Makefile" ]; then
    sed -i '/^install-headers: install-headers-nosubdir/ s|$| $(inst_includedir)/$(lib-names-h-abi)|' "Makefile"
else
    echo "Makefile not found on $BRANCH, skipping"
    return 1
fi

echo "Replacing __builtin_strstr -> strstr in ./configure"
if [ -f ./configure ]; then
    sed -i 's/__builtin_strstr/strstr/g' ./configure
    sed -i 's/4\.\[3-9\]\.\* | 4\.\[1-9\]\[0-9\]\.\* | \[5-9\]\.\* )/4.[3-9].* | 4.[1-9][0-9].* | [5-9].* | [1-9][0-9].* )/' ./configure
    sed -i 's/3\.79\* | 3\.\[89\]\*)/3.79* | 3.[89]* | [4-9].* | [1-9][0-9].*)/' ./configure

    # Backport glibc bb931195fe780bb63e3d57d0742abad1d2128424 (2.18):
    # keep the target preprocessor without requiring installed libc headers.
    if [[ "$1" == 2.17 ]]; then
        sed -i '/^# On Suns, sometimes \$CPP names a directory\./,/^# We need the C++ compiler only for testing\./c\
if test -n "$CPP" \&\& test -d "$CPP"; then\
  CPP=\
fi\
if test -z "$CPP"; then\
  CPP="$CC -E"\
fi\
echo "$CPP"\
\
# We need the C++ compiler only for testing.' ./configure
    fi

    # Old configure scripts require runtime linker features even for headers.
    # Keep the probe results, but allow targets that LLD cannot link.
    if [[ $(echo "$1 < 2.28" | bc) -eq 1 ]]; then
        sed -i 's/as_fn_error.*"linker with -z \(nodelete\|nodlopen\|initfirst\|relro\) support required".*/: # install-headers does not link glibc/' ./configure
    fi
fi

echo "Emptying optional configure files if they exist"
for file in \
    sysdeps/ieee754/ldbl-opt/configure \
    sysdeps/powerpc/powerpc64/le/configure \
    sysdeps/unix/sysv/linux/powerpc/configure
do
    if [ -f "$file" ]; then
        : > "$file"
    fi
done
