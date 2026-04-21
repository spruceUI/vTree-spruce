# vTree-spruce

Cross-compiled [vTree](https://github.com/MustardOS/vtree) builds for spruceOS.

vTree is a gamepad-driven twin-panel file manager for handheld Linux devices, built with SDL2 / SDL2_ttf / SDL2_image.

## Targets

| Target | Toolchain | Devices |
|--------|-----------|---------|
| `vtree-aarch64.tar.gz` | Ubuntu 20.04 multiarch (glibc 2.31) | TrimUI Brick, Smart Pro S, Miyoo Flip |
| `vtree-a30.tar.gz` | A30 buildroot (glibc 2.23, armhf) | Miyoo A30 |
| `vtree-mini.tar.gz` | aemiii91/miyoomini-toolchain (armhf), linked against spruce's custom SDL2 | Miyoo Mini / Mini+ |

## Workflows

- `Build All` — fans out to all three targets
- `Build vTree (aarch64)` — universal aarch64
- `Build vTree (A30)` — Miyoo A30
- `Build vTree (Miyoo Mini)` — Miyoo Mini / Mini+

Each workflow accepts an optional `vtree_version` input (branch / tag / commit SHA) — defaults to `v1.1`. Use `main` for bleeding-edge builds.

Artifacts are uploaded to a `beta-<branch>` prerelease on this repo.

## Layout

```
Dockerfile              — aarch64 (multiarch libsdl2-*-dev:arm64)
Dockerfile.a30          — A30 buildroot + SDL2_ttf/SDL2_image from source
Dockerfile.miyoomini    — aemiii91 toolchain, linked against spruce's custom SDL2 stack
build.sh                — aarch64 build script
build-a30.sh            — A30 build script
build-miyoomini.sh      — Miyoo Mini build script
patches/common/         — patches applied to every target
patches/a30/            — A30-only patches
patches/miyoomini/      — Miyoo Mini-only patches
```

## Output contents

Each tarball contains the `vtree` binary plus runtime assets from the upstream repo (`res/`, `fonts/`, `config.ini`, `theme.ini`, `gamecontrollerdb.txt`).

- **aarch64**: no bundled libs — devices provide libsdl2 stack.
- **A30**: bundles `libs/libSDL2_ttf.so.*` and `libs/libSDL2_image.so.*` (built from source against the A30 buildroot SDL2; the A30 rootfs ships SDL2 but not TTF/Image).
- **Mini**: no bundled libs. Built against the custom SDL2 stack at `spruceUI/spruceOS:miyoo/lib/` so the DT_NEEDED entries match the libraries already on-device. The Miyoo build workflow has a `spruce_ref` input to pin which spruceOS ref the libs are pulled from (defaults to `main`).
