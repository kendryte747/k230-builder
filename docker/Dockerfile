# K230 Docker Image (Single Image - 4 Toolchains)
#
# Design: Single image, users control which toolchains to download at runtime
# via ENABLE_TC{1-4} build args or environment variables.
#
# Toolchains:
#   TC1: Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.6.0 (RTOS U-Boot/OpenSBI)
#   TC2: Xuantie-900-gcc-linux-6.6.0-glibc-x86_64-V3.0.2 (Linux SDK main)
#   TC3: riscv64-linux-musleabi (RTOS RT-Smart)
#   TC4: riscv64ilp32-elf (Linux ILP32 kernel)
#
# Build:
#   docker build -t k230-builder:latest -f docker/Dockerfile .
#
# Run:
#   docker run --rm -it -v k230_toolchains:/opt/toolchains k230-builder:latest bash

FROM ubuntu:22.04

# Toolchain enable flags (default: all enabled)
ARG ENABLE_TC1=1
ARG ENABLE_TC2=1
ARG ENABLE_TC3=1
ARG ENABLE_TC4=1

# Convert ARG to ENV for runtime use
ENV ENABLE_TC1=${ENABLE_TC1}
ENV ENABLE_TC2=${ENABLE_TC2}
ENV ENABLE_TC3=${ENABLE_TC3}
ENV ENABLE_TC4=${ENABLE_TC4}

ENV DEBIAN_FRONTEND=noninteractive

# Install packages based on official kendryte Dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    python3 \
    python3-pip \
    python-is-python3 \
    python3-venv \
    ninja-build \
    bzip2 \
    gzip \
    gosu \
    # Core build tools (from kendryte)
    make \
    patch \
    perl \
    tar \
    cpio \
    unzip \
    rsync \
    file \
    bc \
    findutils \
    sed \
    binutils \
    diffutils \
    bash \
    # Libraries
    libncurses-dev \
    libssl-dev \
    # Parser generators
    bison \
    flex \
    # Extra utilities
    gawk \
    bash-completion \
    parted \
    scons \
    # .NET Runtime (for nncase v2)
    dotnet-runtime-7.0 \
    libicu-dev \
    # Docker CLI
    docker.io \
    # genimage dependencies
    libconfuse-dev \
    libffi-dev \
    pkg-config \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages for K230 SDK
RUN pip3 install --no-cache-dir \
    gmssl \
    pycryptodome \
    jsonschema \
    jinja2

# Install repo tool from Google
RUN mkdir -p /opt/repo && \
    curl -s https://storage.googleapis.com/git-repo-downloads/repo > /opt/repo/repo && \
    chmod +x /opt/repo/repo && \
    mv /opt/repo/repo /usr/local/bin/

# Install genimage (required for building K230 images)
RUN wget -q https://github.com/pengutronix/genimage/releases/download/v16/genimage-16.tar.xz -O /tmp/genimage.tar.xz && \
    cd /tmp && tar -xf genimage.tar.xz && \
    cd genimage-16 && \
    ./configure && make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/genimage*

# Toolchain paths (SDK compatible)
# Create symlink for SDK compatibility (/opt/toolchain -> /opt/toolchains)
RUN ln -sf /opt/toolchains /opt/toolchain
ENV SDK_TOOLCHAIN_DIR=/opt/toolchain
ENV K230_TOOLCHAIN_ROOT=/opt/toolchains

# Create mount points
RUN mkdir -p /opt/toolchains

VOLUME ["/opt/toolchains"]

# Copy scripts
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/toolchain.sh /usr/local/bin/toolchain.sh
COPY scripts/env.sh /usr/local/bin/env.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/toolchain.sh /usr/local/bin/env.sh

ENTRYPOINT ["/entrypoint.sh"]
