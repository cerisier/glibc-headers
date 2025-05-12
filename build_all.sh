#!/bin/bash

set -euo pipefail

for version in $(seq 41 -1 28); do
    version=2.$version
    echo "Building glibc version $version"
    
    docker build \
        --progress=plain \
        --build-arg GLIBC_VERSION=$version \
        -f Dockerfile \
        -t glibc-headers:$version .;

    mkdir headers
    docker create --name extract-headers-$version glibc-headers:$version /bin/true
    docker cp extract-headers-$version:/glibc/headers/$version headers/$version
    docker rm extract-headers-$version

done
