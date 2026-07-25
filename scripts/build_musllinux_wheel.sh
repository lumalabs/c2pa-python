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
# Requires: docker, git.

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

WORKDIR="${TMPDIR:-/tmp}/c2pa-musllinux-build-$$"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

mkdir -p "$WORKDIR"
git clone --depth 1 --branch "$C2PA_RS_TAG" https://github.com/contentauth/c2pa-rs.git "$WORKDIR/c2pa-rs"

mkdir -p "$OUT_DIR"
docker run --rm --platform linux/amd64 \
  -v "$ROOT:/c2pa-python:ro" \
  -v "$WORKDIR/c2pa-rs:/c2pa-rs" \
  -v "$OUT_DIR:/out" \
  -w /tmp/build \
  "$PYTHON_IMAGE" \
  sh -c "
set -eux
apk add --no-cache build-base rust cargo openssl-dev pkgconfig git
cp -a /c2pa-python/. /tmp/build/
rm -rf artifacts build dist src/c2pa/libs
mkdir -p artifacts/$ARTIFACT_PLATFORM src/c2pa/libs

cd /c2pa-rs
cargo build --release -p c2pa-c-ffi --features file_io
cp target/release/libc2pa_c.so /tmp/build/artifacts/$ARTIFACT_PLATFORM/
cp target/release/libc2pa_c.so /tmp/build/src/c2pa/libs/
ldd target/release/libc2pa_c.so

cd /tmp/build
pip install -q -r requirements.txt -r requirements-dev.txt build wheel 'setuptools>=68' toml
python setup.py bdist_wheel --plat-name $PLATFORM_TAG
ls -la dist/
cp dist/*.whl /out/
pip install -q dist/*.whl
python -c 'import c2pa; c=c2pa.Context(); c.__enter__(); c.__exit__(None,None,None); print(\"import_ok\", c2pa.__file__)'
"

echo "Wheels written to $OUT_DIR:"
ls -la "$OUT_DIR"/*.whl
