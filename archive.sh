#!/bin/bash

set -eux

DATE=$(date +%Y%m%d)

for header_dir in headers/*; do
    version=$(basename "$header_dir")
    tag_name="${version}-${DATE}"
    echo "Processing $header_dir, tag $tag_name"

    assets=()

    tar czf "${tag_name}.tar.gz" -C "headers" "$version"
    tar cf - -C "headers" "$version" | zstd -19 -o "${tag_name}.tar.zst"

    sha256sum "${tag_name}.tar.gz" >> sha256sums.txt
    sha256sum "${tag_name}.tar.zst" >> sha256sums.txt

    assets+=("${tag_name}.tar.gz")
    assets+=("${tag_name}.tar.zst")

    for sub_dir in "$header_dir"/*; do
        if [ -d "$sub_dir" ]; then
            target_name=$(basename "$sub_dir")
            archive_name="${target_name}.${version}"

            tar czf "${archive_name}.tar.gz" -C "$(dirname "$sub_dir")" "$target_name"
            tar cf - -C "$(dirname "$sub_dir")" "$target_name" | zstd -19 -o "${archive_name}.tar.zst"

            sha256sum "${archive_name}.tar.gz" >> sha256sums.txt
            sha256sum "${archive_name}.tar.zst" >> sha256sums.txt

            assets+=("${archive_name}.tar.gz")
            assets+=("${archive_name}.tar.zst")
        fi
    done

    assets+=("sha256sums.txt")

    git tag "$tag_name"
    git push origin "$tag_name"

    release_body="Release for $tag_name"
    gh release create "$tag_name" -t "$tag_name" -n "$release_body" "${assets[@]}"

    # gh release upload "$tag_name" "${assets[@]}" --clobber

    rm "${assets[@]}"
done
