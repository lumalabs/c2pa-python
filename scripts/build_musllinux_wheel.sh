#!/usr/bin/env sh
# Build a musllinux_1_2_x86_64 wheel of c2pa-python for Alpine (musl).
#
# Upstream only publishes manylinux (glibc) wheels. This script clones the
# c2pa-rs tag from c2pa-native-version.txt, builds c2pa-c-ffi inside
# python:3.14-alpine, and packs a musllinux wheel into dist/.
#
# Usage (from repo root):
#   ./scripts/build_musllinux_wheel.sh
#   OUT_DIR=/tmp/wheels ./scripts/build_musllinux_wheel.sh
#
# Requires: docker.

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
C2PA_RS_TAG="$(tr -d '[:space:]' <"$ROOT/c2pa-native-version.txt")"
OUT_DIR="${OUT_DIR:-$ROOT/dist}"
PLATFORM_TAG="musllinux_1_2_x86_64"
# setup.py only knows gnu artifact folder names; the wheel tag is set via --plat-name.
ARTIFACT_PLATFORM="x86_64-unknown-linux-gnu"
PYTHON_IMAGE="${PYTHON_IMAGE:-python:3.14-alpine}"

echo "c2pa-rs tag: $C2PA_RS_TAG"
echo "python image: $PYTHON_IMAGE"
echo "wheel tag: $PLATFORM_TAG"

mkdir -p "$OUT_DIR"
# Clone + cargo target stay inside the container so host cleanup never hits
# root-owned files from a bind-mounted target/ directory.
docker run --rm --platform linux/amd64 \
  -e C2PA_RS_TAG="$C2PA_RS_TAG" \
  -e ARTIFACT_PLATFORM="$ARTIFACT_PLATFORM" \
  -e PLATFORM_TAG="$PLATFORM_TAG" \
  -v "$ROOT:/c2pa-python:ro" \
  -v "$OUT_DIR:/out" \
  -w /tmp/build \
  "$PYTHON_IMAGE" \
  sh -c '
set -eux
# perl: required to configure vendored openssl-src during cargo build
apk add --no-cache build-base rust cargo openssl-dev pkgconfig git perl
cp -a /c2pa-python/. /tmp/build/
rm -rf artifacts build dist src/c2pa/libs
mkdir -p "artifacts/$ARTIFACT_PLATFORM" src/c2pa/libs

git clone --depth 1 --branch "$C2PA_RS_TAG" https://github.com/contentauth/c2pa-rs.git /tmp/c2pa-rs
cd /tmp/c2pa-rs
cargo build --release -p c2pa-c-ffi --features file_io
cp target/release/libc2pa_c.so "/tmp/build/artifacts/$ARTIFACT_PLATFORM/"
cp target/release/libc2pa_c.so /tmp/build/src/c2pa/libs/
ldd target/release/libc2pa_c.so

cd /tmp/build
pip install -q -r requirements.txt -r requirements-dev.txt build wheel "setuptools>=68" toml
python setup.py bdist_wheel --plat-name "$PLATFORM_TAG"
ls -la dist/
cp dist/*.whl /out/
pip install -q dist/*.whl
python -c "import c2pa; c=c2pa.Context(); c.__enter__(); c.__exit__(None,None,None); print(\"import_ok\", c2pa.__file__)"
'

echo "Wheels written to $OUT_DIR:"
ls -la "$OUT_DIR"/*.whl
