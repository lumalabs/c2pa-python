# Musllinux wheels (this fork)

## Why this exists

Upstream [contentauth/c2pa-python](https://github.com/contentauth/c2pa-python) publishes **manylinux** (glibc) wheels only.

Alpine (`python:*-alpine`, **musl**) cannot load those wheels; the sdist pulls gnu natives that fail at `dlopen`; compiling Rust inside every image build is too slow.

This fork builds and publishes **musllinux** wheels so Alpine can `import c2pa` without a per-image Rust compile. The Python API is unchanged. macOS and glibc Linux keep using PyPI.

Active surface area (keep this small):

| Path | Purpose |
| --- | --- |
| `scripts/build_musllinux_wheel.sh` | Build musllinux wheel in Docker |
| `.github/workflows/build-musllinux-wheel.yml` | CI + GitHub Release on `v*-musl*` tags |
| `MUSLLINUX.md` | This file |

Upstream Adobe Actions (Build/PyPI, Pages, Jira ticket labels, memray) are **disabled** here so musl tags do not fan out into their matrix or publish to PyPI.

## How to upgrade

When Adobe ships a new `c2pa-python` / `c2pa-rs` pair:

1. **Fetch upstream** into this fork (rebase or merge `contentauth/c2pa-python` `main`).
2. **Re-apply fork bits** if the upgrade wiped them:
   - `scripts/build_musllinux_wheel.sh`
   - `.github/workflows/build-musllinux-wheel.yml`
   - disabled triggers on unused workflows (see below)
   - this `MUSLLINUX.md`
3. **Confirm pins** match the intended Adobe release:
   - `pyproject.toml` → `[project].version` (e.g. `0.37.1`)
   - `c2pa-native-version.txt` → `c2pa-rs` tag (e.g. `c2pa-v0.90.1`)
4. **Build & publish** a musllinux wheel:
   ```bash
   ./scripts/build_musllinux_wheel.sh
   # or push a tag and let CI do it:
   git tag v<version>-musl.1   # e.g. v0.37.1-musl.1
   git push origin v<version>-musl.1
   ```
   Tag shape: `v<python-package-version>-musl.<n>`  
   Bump `<n>` for a rebuild of the same Adobe version (link flags, script fixes).
5. **Consume** from the release (example with uv):

   ```toml
   dependencies = [
     "c2pa-python==0.37.1",
   ]

   [tool.uv]
   # Prefer releases/expanded_assets/<tag> if /releases/download/<tag>/ 404s as a directory.
   find-links = [
     "https://github.com/<org>/<repo>/releases/expanded_assets/v0.37.1-musl.1",
   ]
   ```

   Do **not** set `c2pa-python = { url = "...musllinux....whl" }` — that forces one platform everywhere. Use find-links + wheel tags so macOS/glibc still take PyPI.

### Local build

Requires Docker (linux/amd64):

```bash
./scripts/build_musllinux_wheel.sh
OUT_DIR=/tmp/wheels ./scripts/build_musllinux_wheel.sh
```

Runtime on Alpine needs `libgcc` / `libstdc++` (apk).

### Disabled upstream Actions

These workflow files are kept for easier upstream merges, but their triggers are stubbed so they do not run on this fork:

- `build.yml` (+ callee `build-wheel.yml`) — Adobe multi-platform Build / PyPI publish
- `publish-docs.yml` — GitHub Pages
- `memory-benchmark.yml`
- `closing_ticket.yml` / `labeling_ticket_*.yml` / `reopening_ticket.yml` — Adobe Jira label sync

Only `build-musllinux-wheel.yml` should run automatically (on `v*-musl*` tags or `workflow_dispatch`).

## Current pin

- Package: `0.37.1`
- Native: `c2pa-v0.90.1`
- Release tag: `v0.37.1-musl.1`
