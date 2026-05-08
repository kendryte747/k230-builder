#!/bin/bash
set -e

# ============================================
# build.sh - Build k230-builder image
# ============================================
# Version: git-commit-count + short hash (e.g. 6-bdba399)
# Usage:
#   ./build.sh              # build with auto version
#   ./build.sh --no-cache   # force full rebuild
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKERFILE="$SCRIPT_DIR/docker/Dockerfile"
IMAGE_NAME="${IMAGE_NAME:-k230-builder}"

# ---- Compute version ----
GIT_COUNT=$(git -C "$SCRIPT_DIR" rev-list --count HEAD)
GIT_SHORT=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD)
VERSION="${GIT_COUNT}-${GIT_SHORT}"

# ---- Check workspace cleanliness ----
if ! git -C "$SCRIPT_DIR" diff --quiet HEAD --; then
    VERSION="${VERSION}-dirty"
fi

# ---- Parse args ----
BUILD_ARGS=""
while [ $# -gt 0 ]; do
    case "$1" in
        --no-cache)
            BUILD_ARGS="$BUILD_ARGS --no-cache"
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--no-cache]"
            exit 1
            ;;
    esac
    shift
done

echo "[k230] Building $IMAGE_NAME:$VERSION"
echo "[k230] Dockerfile: $DOCKERFILE"

docker build \
    $BUILD_ARGS \
    -f "$DOCKERFILE" \
    -t "$IMAGE_NAME:$VERSION" \
    -t "$IMAGE_NAME:latest" \
    "$SCRIPT_DIR"

echo "[k230] Build complete: $IMAGE_NAME:$VERSION"
echo "[k230] Tags: $IMAGE_NAME:$VERSION, $IMAGE_NAME:latest"
