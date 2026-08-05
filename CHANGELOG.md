# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2026-08-04

Rewrite. The tap is now a thin, tracked derivative of homebrew-core's `qemu`
rather than an independent fork with patched dependencies.

### Changed

- **`qemu-spice` rebased on homebrew-core's `qemu` 11.0.3** (was 10.1.2, an
  independently maintained formula). The formula is now core's, with the SPICE
  changes confined to blocks marked `SPICE divergence`.
- Adopted core's current build setup: `pkgconf` instead of `pkg-config`,
  `python@3.14` + `python-setuptools` instead of `python@3.12`, the
  `python/wheels` pruning step, and the `--smbd=` and `--cc/--host-cc` flags.
- Added `conflicts_with "qemu"`. Both formulas install `qemu-system-*` binaries;
  the previous formula silently clobbered core qemu's symlinks instead of
  declaring the conflict.
- `Makefile` reduced from 348 lines to the targets that still apply.
- README, `docs/INSTALL.md` and `docs/KNOWN-ISSUES.md` rewritten to describe
  what the build actually does.

### Removed

- **`libepoxy-egl` formula** — a patched fork of libepoxy 1.5.10. Two of its
  three patch hunks have since been merged upstream (anholt/libepoxy#239 and
  #314); the third was already a no-op because the formula passed `-Degl=yes`
  explicitly. It also conflicted with core `libepoxy`.
- **`virglrenderer` formula** — pinned to revision `0a26988c…` of
  akihikodaki/virglrenderer, which does not exist in that repository
  (`upload-pack: not our ref`), so a clean install could not fetch it. The
  `macos` branch it tracked has had no commits since 2023-12-10.
- **`--enable-opengl` and `--enable-virglrenderer`** from the QEMU configure
  line, and the `libepoxy-egl`/`virglrenderer` dependencies.

  These could never do anything on macOS. QEMU gates its SPICE GL support on
  `HAVE_SPICE_GL`, which requires `CONFIG_OPENGL && CONFIG_GBM`
  (`include/ui/spice-display.h`). GBM is a Mesa/DRM component with no macOS
  implementation. Verified against the 10.1.2 build this replaces:
  `-spice gl=on` → `Invalid parameter 'gl'`; `-display cocoa,gl=on` →
  `OpenGL is not supported by display backend 'cocoa'`; `-device virtio-gpu-gl`
  → `The display backend does not have OpenGL support enabled`;
  `-display egl-headless` → `egl: not available on this platform`.
- **`-march=armv8.5-a -mtune=native -O3` CFLAGS.** `-mtune=native` makes the
  build machine-specific, and core does not do this.
- **`qemu-spice-vm` wrapper script.** It ran `qemu-system-x86_64 -machine
  type=q35,accel=hvf`, which fails on Apple Silicon with
  `invalid accelerator hvf` — HVF only accelerates a guest matching the host
  architecture. It also passed `-display cocoa,gl=on`, `-device virtio-vga-gl`
  and `-spice gl=on`, none of which work on macOS. Replaced by a working,
  documented command line in the README.

### Added

- **`scripts/sync-check.sh`** (`make sync-check`) — reports drift between this
  formula and homebrew-core's live `qemu` formula across version, sha256,
  dependencies and configure arguments, ignoring the intentional SPICE
  differences. Exits non-zero on drift. Also flags the case where core adds
  `spice-server` itself, which would make this tap unnecessary.
- Weekly CI job running the drift check.
- Formula test now asserts SPICE is actually compiled in — `-spice help` must
  list options, and `qxl`/`usb-redir` must appear in `-device help`. The old
  test asserted `qxl` only, which does not distinguish a SPICE build.

### Fixed

- Corrected README claims of "GPU acceleration via virglrenderer",
  "OpenGL/EGL", and "x86_64 guests: ~80% of bare metal with HVF". None were
  achievable on this platform.

### Verified

QEMU 11.0.3 built from source on Apple Silicon; `brew audit --strict` and
`brew style` clean; `brew test` passing; live VM under HVF serving SPICE on a
TCP port with a valid `REDQ` protocol handshake, vdagent channel, USB
redirection and CoreAudio attached.

## [1.0.0] - 2025-10-25

### Initial Release

Homebrew tap providing QEMU 10.1.2 with SPICE protocol support, optimized for Apple Silicon.

#### Formulas

- **qemu-spice** - QEMU 10.1.2 with SPICE support and Apple Silicon optimizations
- **spice-server** - SPICE server library 0.15.2 (later replaced by the homebrew-core formula)
- **virglrenderer** - Virtual GPU renderer using akihikodaki's macOS fork (removed in 2.0.0)
- **libepoxy-egl** - OpenGL function pointer library 1.5.10 with EGL patches for macOS (removed in 2.0.0)

#### Supported Architectures

- aarch64-softmmu (ARM 64-bit)
- x86_64-softmmu (Intel/AMD 64-bit)
- arm-softmmu (ARM 32-bit)
- i386-softmmu (Intel 32-bit)
- riscv64-softmmu (RISC-V 64-bit)
- riscv32-softmmu (RISC-V 32-bit)

#### Credits

Based on [avoidik/homebrew-qemu-spice](https://github.com/avoidik/homebrew-qemu-spice) with enhancements for Apple Silicon.
