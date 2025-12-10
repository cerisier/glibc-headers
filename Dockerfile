FROM ubuntu:25.04 as downloader

ARG GLIBC_VERSION=2.38

RUN apt update && apt install -y git clang-20 make gawk bison wget lbzip2 zstd jq
RUN git clone --depth 1 --branch release/$GLIBC_VERSION/master https://sourceware.org/git/glibc.git /glibc

COPY glibc_kernel_versions.txt /glibc_kernel_versions.txt
RUN cat /glibc_kernel_versions.txt

RUN set -x && export KERNEL_VERSION=$(cat /glibc_kernel_versions.txt | grep $GLIBC_VERSION | cut -f2) && \
    wget -O /index.json https://cerisier.github.io/kernel-headers/index.json && \
    export DOWNLOAD_URL=$(cat /index.json | jq -r ".[\"$KERNEL_VERSION\"] | to_entries | .[0].value.url") && \
    export FILENAME=$(basename "$DOWNLOAD_URL") && \
    wget "$DOWNLOAD_URL" -O "$FILENAME" && ls $FILENAME && \
    tar -xvf "$FILENAME" && \
    mv /$KERNEL_VERSION /kernel-headers

FROM downloader as builder

ARG GLIBC_VERSION=2.38

WORKDIR /

COPY apply_patches.sh /apply_patches.sh
COPY build.sh /build.sh 

WORKDIR /glibc

RUN bash /apply_patches.sh ${GLIBC_VERSION}

ENV KERNEL_HEADERS_BASE_DIR=/kernel-headers
RUN bash /build.sh ${GLIBC_VERSION}

FROM scratch as export

ARG GLIBC_VERSION=2.38

COPY --from=builder /glibc/headers/$GLIBC_VERSION /headers
COPY --from=builder /bin/true /bin/true
