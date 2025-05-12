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
