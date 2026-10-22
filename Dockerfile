FROM ubuntu:25.04 as downloader

ARG GLIBC_VERSION=2.38

RUN apt update && apt install -y git clang-20 lld-20 make gawk bison wget lbzip2 zstd jq bc && \
    printf '%s\n' \
        '#!/bin/sh' \
        'if [ "$1" = "--version" ]; then' \
        '  echo "GNU ld (GNU Binutils) 2.44"' \
        '  exit 0' \
        'fi' \
        'case " $* " in' \
        '  *" --help "*)' \
        '    /usr/bin/ld.lld-20 "$@" || true' \
        '    printf "%s\n" "-z nodelete" "-z nodlopen" "-z initfirst" "--version-script"' \
        '    exit 0' \
        '    ;;' \
        'esac' \
        'exec /usr/bin/ld.lld-20 "$@"' \
        > /usr/local/bin/ld && \
    chmod +x /usr/local/bin/ld
RUN git clone --depth 1 --branch release/$GLIBC_VERSION/master https://sourceware.org/git/glibc.git /glibc

COPY glibc_kernel_versions.txt /glibc_kernel_versions.txt
RUN cat /glibc_kernel_versions.txt

RUN set -x && export KERNEL_VERSION=$(cat /glibc_kernel_versions.txt | grep $GLIBC_VERSION | cut -f2) && \
    wget -O /index.json https://cerisier.github.io/kernel-headers/index.json && \
    mkdir /kernel-headers && \
    jq -r ".[\"$KERNEL_VERSION\"][].url" /index.json | while read -r DOWNLOAD_URL; do \
        wget -qO- "$DOWNLOAD_URL" | tar --zstd -xf - -C /kernel-headers; \
    done

FROM downloader as builder

ARG GLIBC_VERSION=2.38
ARG TARGETS

WORKDIR /

COPY apply_patches.sh /apply_patches.sh
COPY build.sh /build.sh 

WORKDIR /glibc

RUN bash /apply_patches.sh ${GLIBC_VERSION}

ENV KERNEL_HEADERS_BASE_DIR=/kernel-headers
RUN TARGETS="${TARGETS}" bash /build.sh ${GLIBC_VERSION}

FROM scratch as export

ARG GLIBC_VERSION=2.38

COPY --from=builder /glibc/headers/$GLIBC_VERSION /headers
COPY --from=builder /bin/true /bin/true
