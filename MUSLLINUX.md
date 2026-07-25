# Musllinux wheels (Luma fork)

Upstream [contentauth/c2pa-python](https://github.com/contentauth/c2pa-python) publishes **manylinux** (glibc) wheels only. Luma Vespa runs on `python:3.14-alpine` (**musl**), so those wheels cannot load. This fork builds and publishes **musllinux** wheels so Alpine can `import c2pa` without compiling Rust in every Docker build.

macOS and glibc Linux keep using PyPI manylinux/macOS wheels. Do not force a single wheel URL for all platforms.

## Local build

Requires Docker (linux/amd64) and git:

```bash
./scripts/build_musllinux_wheel.sh
# or:
OUT_DIR=/tmp/wheels ./scripts/build_musllinux_wheel.sh
```

The script:

1. Reads the `c2pa-rs` tag from `c2pa-native-version.txt`
2. Shallow-clones `contentauth/c2pa-rs` at that tag
3. Builds `c2pa-c-ffi` inside `python:3.14-alpine`
4. Packs `c2pa_python-<ver>-py3-none-musllinux_1_2_x86_64.whl` into `dist/` (or `OUT_DIR`)
5. Smoke-tests `import c2pa` and `c2pa.Context()` in the same container

Runtime on Alpine needs `libgcc` / `libstdc++` (apk). The packaged `.so` links against musl (`ld-musl-x86_64.so.1`).

## Release / tag convention

```
v<python-package-version>-musl.<n>
```

Examples: `v0.37.1-musl.1`, `v0.37.1-musl.2` (rebuild for link flags without a new Adobe API version).

Pushing a matching tag runs [`.github/workflows/build-musllinux-wheel.yml`](.github/workflows/build-musllinux-wheel.yml), uploads the wheel artifact, and creates a GitHub Release with the `.whl` attached. `workflow_dispatch` builds without releasing.

Current Vespa pin target:

`https://github.com/lumalabs/c2pa-python/releases/download/v0.37.1-musl.1/`

## Bump runbook (next Adobe version)

1. Merge/rebase upstream `contentauth/c2pa-python` into this fork
2. Confirm `pyproject.toml` `[project].version` and `c2pa-native-version.txt` match the intended Adobe pair
3. Tag `v<version>-musl.1` (or bump `.n` for a rebuild of the same Python version)
4. Wait for CI to publish the Release asset
5. In Vespa (`luma-core`): update `[tool.uv] find-links` to the new release URL, keep `c2pa-python==<version>`, run `uv lock`, verify Alpine `uv sync` + `import c2pa`

## Vespa consume pattern

Use **find-links** plus the musllinux platform tag. Do **not** put Alpine vs not in `[tool.uv.sources]` markers, and do **not** set a direct `url = "...musllinux....whl"` source (that forces one platform everywhere).

```toml
dependencies = [
  "c2pa-python==0.37.1",
]

[tool.uv]
find-links = [
  "https://github.com/lumalabs/c2pa-python/releases/download/v0.37.1-musl.1/",
]
```

Keep existing path sources (`error-taxonomy`, etc.) unchanged. On Alpine, uv selects the musllinux wheel from find-links; on macOS/glibc it keeps using PyPI.

## Out of scope

- aarch64 musllinux (unless we ship Alpine arm64 workers)
- Rewriting Vespa `ComplianceSigner` / CLI (`c2patool`)
- Upstreaming musllinux to Adobe (nice later)
