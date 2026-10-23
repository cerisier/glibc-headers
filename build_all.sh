#!/bin/bash

set -euo pipefail

GLIBC_VERSIONS_FILE="glibc_versions.txt"
if [[ $# -gt 0 ]]; then
    GLIBC_VERSIONS=("$@")
else
    GLIBC_VERSIONS=(
        $(git diff --unified=0 "$GLIBC_VERSIONS_FILE" | sed -n 's/^+\([0-9].*\)/\1/p')
    )
fi

for version in "${GLIBC_VERSIONS[@]}"; do
    if ! grep -Fxq -- "$version" "$GLIBC_VERSIONS_FILE"; then
        echo "Unknown glibc version: $version" >&2
        exit 1
    fi
    if [[ -e "headers/$version" ]]; then
        echo "Output already exists: headers/$version" >&2
        exit 1
    fi
done

for version in "${GLIBC_VERSIONS[@]}"; do
    # version=2.$version
    echo "Building glibc version $version"
    
    docker build \
        --progress=plain \
        --build-arg GLIBC_VERSION=$version \
        --build-arg TARGETS="${TARGETS:-}" \
        -f Dockerfile \
        -t glibc-headers:$version .;

    mkdir -p headers
    docker create --name extract-headers-$version glibc-headers:$version /bin/true
    docker cp extract-headers-$version:/headers headers/$version
    docker rm extract-headers-$version

done
