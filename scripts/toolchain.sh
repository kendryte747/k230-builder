#!/bin/bash
set -e
set -u

TOOLCHAIN_ROOT=${K230_TOOLCHAIN_ROOT:-/opt/toolchains}

# ===== Default: all toolchains enabled =====
ENABLE_TC1=${ENABLE_TC1:-1}
ENABLE_TC2=${ENABLE_TC2:-1}
ENABLE_TC3=${ENABLE_TC3:-1}
ENABLE_TC4=${ENABLE_TC4:-1}

# ===== TC1: Xuantie-900 gcc 5.10.4 (glibc, bz2) =====
TC1_URLS=${TC1_URLS:-"https://kendryte-download.canaan-creative.com/k230/toolchain/Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.6.0.tar.bz2"}
TC1_VERSION=${TC1_VERSION:-"V2.6.0"}
TC1_DIR=${TC1_DIR:-"Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.6.0"}
TC1_BIN=${TC1_BIN:-"riscv64-unknown-linux-gnu-gcc"}
TC1_BIN_FULL="bin/${TC1_BIN}"

# ===== TC2: Xuantie-900 gcc 6.6.0 (glibc, gz) =====
TC2_URLS=${TC2_URLS:-"https://kendryte-download.canaan-creative.com/k230/downloads/dl/gcc/Xuantie-900-gcc-linux-6.6.0-glibc-x86_64-V3.0.2-20250410.tar.gz"}
TC2_VERSION=${TC2_VERSION:-"V3.0.2"}
TC2_DIR=${TC2_DIR:-"Xuantie-900-gcc-linux-6.6.0-glibc-x86_64-V3.0.2"}
TC2_BIN=${TC2_BIN:-"riscv64-unknown-linux-gnu-gcc"}
TC2_BIN_FULL="bin/${TC2_BIN}"

# ===== TC3: musl (RT-Smart, bz2) =====
TC3_URLS=${TC3_URLS:-"https://kendryte-download.canaan-creative.com/k230/toolchain/riscv64-unknown-linux-musl-rv64imafdcv-lp64d-20230420.tar.bz2"}
TC3_VERSION=${TC3_VERSION:-"20230420"}
TC3_DIR=${TC3_DIR:-"riscv64-linux-musleabi_for_x86_64-pc-linux-gnu"}
TC3_BIN=${TC3_BIN:-"riscv64-unknown-linux-musl-gcc"}
TC3_BIN_FULL="bin/${TC3_BIN}"

# ===== TC4: ILP32 elf (riscv/ subdirectory, gz) =====
TC4_URLS=${TC4_URLS:-"https://github.com/ruyisdk/riscv-gnu-toolchain-rv64ilp32/releases/download/2024.06.25/riscv64ilp32-elf-ubuntu-22.04-gcc-nightly-2024.06.25-nightly.tar.gz"}
TC4_VERSION=${TC4_VERSION:-"2024.06.25"}
TC4_DIR=${TC4_DIR:-"riscv64ilp32-elf-ubuntu-22.04-gcc-nightly-2024.06.25"}
TC4_BIN=${TC4_BIN:-"riscv64-unknown-elf-gcc"}
TC4_BIN_FULL="riscv/bin/${TC4_BIN}"

# ===== Check if toolchain is already installed and valid =====
# Args: DIR, VERSION, BIN (filename only), BIN_FULL (relative path from DIR)
check_toolchain() {
    local DIR=$1
    local VERSION=$2
    local BIN=$3
    local BIN_FULL=$4

    # 1. Check installation flag
    if [ ! -f "$DIR/.installed" ]; then
        echo "[k230] $DIR/.installed not found"
        return 1
    fi

    # 2. Check version file
    if [ ! -f "$DIR/.version" ]; then
        echo "[k230] $DIR/.version not found"
        return 1
    fi

    # 3. Check version match
    local INSTALLED_VERSION
    INSTALLED_VERSION=$(cat "$DIR/.version")
    if [ "$INSTALLED_VERSION" != "$VERSION" ]; then
        echo "[k230] version mismatch: installed=$INSTALLED_VERSION, expected=$VERSION"
        return 1
    fi

    # 4. Check critical binary exists
    if [ ! -f "$DIR/$BIN_FULL" ]; then
        echo "[k230] binary not found: $DIR/$BIN_FULL"
        return 1
    fi

    return 0
}

# ===== Download with fallback (multiple space-separated URLs) =====
download_with_fallback() {
    local URLS=$1
    local OUTPUT=$2

    for url in $URLS; do
        echo "[k230] trying: $url"
        if curl -L --fail --retry 2 -o "$OUTPUT" "$url" 2>/dev/null; then
            echo "[k230] download success: $url"
            return 0
        fi
        echo "[k230] download failed: $url"
    done

    echo "[k230] error: all download sources failed"
    return 1
}

# ===== Verify MD5 (optional) =====
verify_md5() {
    local FILE=$1
    local MD5_URL=$2

    [ -z "$MD5_URL" ] && return 0

    local TMP_MD5=/tmp/file.md5

    if curl -L --fail -o "$TMP_MD5" "$MD5_URL" 2>/dev/null; then
        echo "[k230] md5 file downloaded"
        local EXPECTED=$(awk '{print $1}' "$TMP_MD5")
        local ACTUAL=$(md5sum "$FILE" | awk '{print $1}')

        if [ "$EXPECTED" != "$ACTUAL" ]; then
            echo "[k230] error: md5 mismatch"
            rm -f "$TMP_MD5"
            return 1
        fi
        echo "[k230] md5 verified"
    else
        echo "[k230] warn: md5 not available, skipping verification"
    fi

    rm -f "$TMP_MD5"
    return 0
}

# ===== Install toolchain (generic, handles all 4 TCs) =====
# Args: NAME, VERSION, BIN (filename), BIN_FULL (relative path), URLS, MD5_URL, DIR_NAME, EXTENSION
install_toolchain() {
    local NAME=$1
    local VERSION=$2
    local BIN=$3
    local BIN_FULL=$4
    local URLS=$5
    local MD5_URL=$6
    local DIR_NAME=$7
    local EXTENSION=${8:-"bz2"}

    local DIR=$TOOLCHAIN_ROOT/$DIR_NAME
    local TMP=/tmp/${NAME}.tar.${EXTENSION}

    # Check if already installed and valid
    if check_toolchain "$DIR" "$VERSION" "$BIN" "$BIN_FULL"; then
        echo "[k230] $NAME already installed (version=$VERSION)"
        return 0
    fi

    echo "[k230] installing $NAME (version=$VERSION)..."

    # Clean up old installation
    rm -rf "$DIR"
    mkdir -p "$TOOLCHAIN_ROOT"

    # Download
    download_with_fallback "$URLS" "$TMP"

    # Determine extraction command
    local EXTRACT_CMD=""
    case $EXTENSION in
        bz2) EXTRACT_CMD="tar -xjf" ;;
        gz)  EXTRACT_CMD="tar -xzf" ;;
        xz)  EXTRACT_CMD="tar -xJf" ;;
        *)   EXTRACT_CMD="tar -xf" ;;
    esac

    # Determine list flags
    local LIST_FLAGS=""
    case $EXTENSION in
        bz2) LIST_FLAGS="-tjf" ;;
        gz)  LIST_FLAGS="-tzf" ;;
        xz)  LIST_FLAGS="-tJf" ;;
        *)   LIST_FLAGS="-tf" ;;
    esac

    # Detect actual directory name inside tarball
    local EXTRACTED_DIR
    EXTRACTED_DIR=$(tar $LIST_FLAGS "$TMP" 2>/dev/null | head -1 | sed 's|^\./||' | cut -f1 -d"/")
    echo "[k230] extracted dir: $EXTRACTED_DIR"

    # Extract
    $EXTRACT_CMD "$TMP" -C "$TOOLCHAIN_ROOT"

    # Rename to SDK-expected directory name
    if [ -d "$TOOLCHAIN_ROOT/$EXTRACTED_DIR" ]; then
        if [ "$EXTRACTED_DIR" != "$DIR_NAME" ]; then
            mv "$TOOLCHAIN_ROOT/$EXTRACTED_DIR" "$DIR"
            echo "[k230] renamed $EXTRACTED_DIR -> $DIR_NAME"
        else
            echo "[k230] directory already named $DIR_NAME"
        fi
    else
        echo "[k230] error: unexpected directory structure in tarball"
        exit 1
    fi

    # Verify MD5 (optional)
    if ! verify_md5 "$TMP" "$MD5_URL"; then
        echo "[k230] error: integrity check failed"
        exit 1
    fi

    # Write version info
    echo "$VERSION" > "$DIR/.version"
    touch "$DIR/.installed"

    rm -f "$TMP"

    echo "[k230] $NAME installed (version=$VERSION)"
}

# ===== Download functions for each toolchain =====

download_tc1() {
    install_toolchain \
        "tc1-xuantie-5.10.4" \
        "$TC1_VERSION" \
        "$TC1_BIN" \
        "$TC1_BIN_FULL" \
        "$TC1_URLS" \
        "" \
        "$TC1_DIR" \
        "bz2"
}

download_tc2() {
    install_toolchain \
        "tc2-xuantie-6.6.0" \
        "$TC2_VERSION" \
        "$TC2_BIN" \
        "$TC2_BIN_FULL" \
        "$TC2_URLS" \
        "" \
        "$TC2_DIR" \
        "gz"
}

download_tc3() {
    install_toolchain \
        "tc3-musl" \
        "$TC3_VERSION" \
        "$TC3_BIN" \
        "$TC3_BIN_FULL" \
        "$TC3_URLS" \
        "" \
        "$TC3_DIR" \
        "bz2"
}

download_tc4() {
    install_toolchain \
        "tc4-ilp32" \
        "$TC4_VERSION" \
        "$TC4_BIN" \
        "$TC4_BIN_FULL" \
        "$TC4_URLS" \
        "" \
        "$TC4_DIR" \
        "gz"
}

# ===== Legacy compatibility =====
download_toolchain() {
    local NAME=${1:-}

    case $NAME in
        tc1)  download_tc1 ;;
        tc2)  download_tc2 ;;
        tc3)  download_tc3 ;;
        tc4)  download_tc4 ;;
        linux)  download_tc2 ;;
        rtos)   download_tc3 ;;
        all)
            download_tc1
            download_tc2
            download_tc3
            download_tc4
            ;;
        *)
            echo "[k230] error: unknown toolchain '$NAME'"
            echo "[k230] usage: download_toolchain {tc1|tc2|tc3|tc4|linux|rtos|all}"
            return 1
            ;;
    esac
}

# ===== Setup environment variables =====
# Args: NAME (tc1, tc2, tc3, tc4, linux, rtos, all)
setup_env() {
    local NAME=${1:-all}

    case $NAME in
        tc1)
            export K230_LINUX_TOOLCHAIN=$TOOLCHAIN_ROOT/$TC1_DIR
            export PATH=$K230_LINUX_TOOLCHAIN/bin:$PATH
            ;;
        tc2)
            export K230_LINUX_TOOLCHAIN=$TOOLCHAIN_ROOT/$TC2_DIR
            export PATH=$K230_LINUX_TOOLCHAIN/bin:$PATH
            ;;
        tc3)
            export K230_RTOS_TOOLCHAIN=$TOOLCHAIN_ROOT/$TC3_DIR
            export PATH=$K230_RTOS_TOOLCHAIN/bin:$PATH
            ;;
        tc4)
            export K230_ILP32_TOOLCHAIN=$TOOLCHAIN_ROOT/$TC4_DIR
            export PATH=$K230_ILP32_TOOLCHAIN/riscv/bin:$PATH
            ;;
        linux)
            # linux SDK uses TC2 (6.6.0) as primary
            export K230_LINUX_TOOLCHAIN=$TOOLCHAIN_ROOT/$TC2_DIR
            export PATH=$K230_LINUX_TOOLCHAIN/bin:$PATH
            ;;
        rtos)
            # rtos SDK uses TC3 (musl) as primary
            export K230_RTOS_TOOLCHAIN=$TOOLCHAIN_ROOT/$TC3_DIR
            export PATH=$K230_RTOS_TOOLCHAIN/bin:$PATH
            ;;
        all)
            export K230_LINUX_TOOLCHAIN=$TOOLCHAIN_ROOT/$TC2_DIR
            export K230_RTOS_TOOLCHAIN=$TOOLCHAIN_ROOT/$TC3_DIR
            export K230_ILP32_TOOLCHAIN=$TOOLCHAIN_ROOT/$TC4_DIR
            export PATH=$K230_LINUX_TOOLCHAIN/bin:$K230_RTOS_TOOLCHAIN/bin:$K230_ILP32_TOOLCHAIN/riscv/bin:$PATH
            ;;
        *)
            echo "[k230] error: unknown toolchain '$NAME'"
            echo "[k230] usage: setup_env {tc1|tc2|tc3|tc4|linux|rtos|all}"
            return 1
            ;;
    esac
}
