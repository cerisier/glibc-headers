#!/bin/bash

set -euxo pipefail

# Keep macOS metadata sidecars out of local archives.
export COPYFILE_DISABLE=1

# --local keeps the archives without creating tags or publishing a release.
PUBLISH=yes
if [[ "${1:-}" == --local ]]; then
    PUBLISH=no
    shift
fi

DATE=$(date +%Y%m%d)

GLIBC_KERNEL_VERSIONS_FILE="glibc_kernel_versions.txt"
if [[ $# -gt 0 ]]; then
    GLIBC_VERSIONS=("$@")
else
    GLIBC_VERSIONS=(
        $(git diff --unified=0 "$GLIBC_KERNEL_VERSIONS_FILE" | sed -n 's/^+\([0-9].*\)/\1/p' | cut -f1)
    )
fi

for version in "${GLIBC_VERSIONS[@]}"; do
    if ! awk -v version="$version" '$1 == version { found = 1 } END { exit !found }' "$GLIBC_KERNEL_VERSIONS_FILE"; then
        echo "Unknown glibc version: $version" >&2
        exit 1
    fi
    test -d "headers/$version"
done
headers=("${GLIBC_VERSIONS[@]/#/headers/}")

for header_dir in "${headers[@]}"; do
    version=$(basename "$header_dir")
    tag_name="${version}-${DATE}"
    echo "Processing $header_dir, tag $tag_name"

    assets=()
    CHECKSUM_FILE=sha256sums.txt
    if [[ "$PUBLISH" == no ]]; then
        CHECKSUM_FILE="${tag_name}.sha256sums.txt"
        for asset in "$tag_name".tar.{gz,zst} *."$version".tar.{gz,zst} "$CHECKSUM_FILE"; do
            if [[ -e "$asset" ]]; then
                echo "Output already exists: $asset" >&2
                exit 1
            fi
        done
    fi

    tar czf "${tag_name}.tar.gz" -C "headers" "$version"
    tar cf - -C "headers" "$version" | zstd -19 -o "${tag_name}.tar.zst"

    sha256sum "${tag_name}.tar.gz" > "$CHECKSUM_FILE"
    sha256sum "${tag_name}.tar.zst" >> "$CHECKSUM_FILE"

    assets+=("${tag_name}.tar.gz")
    assets+=("${tag_name}.tar.zst")

    for sub_dir in "$header_dir"/*; do
        if [ -d "$sub_dir" ]; then
            target_name=$(basename "$sub_dir")
            archive_name="${target_name}.${version}"

            tar czf "${archive_name}.tar.gz" -C "$(dirname "$sub_dir")" "$target_name"
            tar cf - -C "$(dirname "$sub_dir")" "$target_name" | zstd -19 -o "${archive_name}.tar.zst"

            sha256sum "${archive_name}.tar.gz" >> "$CHECKSUM_FILE"
            sha256sum "${archive_name}.tar.zst" >> "$CHECKSUM_FILE"

            assets+=("${archive_name}.tar.gz")
            assets+=("${archive_name}.tar.zst")
        fi
    done

    assets+=("$CHECKSUM_FILE")

    if [[ "$PUBLISH" == no ]]; then
        continue
    fi

    git tag "$tag_name"
    git push origin "$tag_name"

    release_body="Release for $tag_name"
    gh release create "$tag_name" -t "$tag_name" -n "$release_body" "${assets[@]}"

    # gh release upload "$tag_name" "${assets[@]}" --clobber

    rm "${assets[@]}"
done
