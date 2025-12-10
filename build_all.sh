#!/bin/bash

set -euo pipefail

GLIBC_KERNEL_VERSIONS_FILE="glibc_kernel_versions.txt"
GLIBC_VERSIONS=(
	$(git diff --unified=0 $GLIBC_KERNEL_VERSIONS_FILE| sed -n 's/^\+\(.*\)/\1/p' | grep -v '+' | cut -f1)
)

for version in "${GLIBC_VERSIONS[@]}"; do
    # version=2.$version
    echo "Building glibc version $version"
    
    docker build \
        --progress=plain \
        --build-arg GLIBC_VERSION=$version \
        -f Dockerfile \
        -t glibc-headers:$version .;

    mkdir -p headers
    docker create --name extract-headers-$version glibc-headers:$version /bin/true
    docker cp extract-headers-$version:/headers headers/$version
    docker rm extract-headers-$version

done
