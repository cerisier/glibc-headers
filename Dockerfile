FROM ubuntu:25.04 as downloader

ARG GLIBC_VERSION=2.38

RUN apt update && apt install -y git clang-20 make gawk bison wget lbzip2
RUN git clone --depth 1 --branch release/$GLIBC_VERSION/master https://sourceware.org/git/glibc.git /glibc

COPY glibc_kernel_versions.txt /glibc_kernel_versions.txt
RUN cat /glibc_kernel_versions.txt

RUN export KERNEL_VERSION=$(cat /glibc_kernel_versions.txt | grep $GLIBC_VERSION | cut -f2) && \
    wget https://github.com/cerisier/kernel-headers/releases/download/$KERNEL_VERSION-20250511/$KERNEL_VERSION-20250511.tar.gz && \
    tar -xzf $KERNEL_VERSION-20250511.tar.gz && \
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
