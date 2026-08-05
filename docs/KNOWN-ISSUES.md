# Known issues and limitations

## There is no GPU acceleration on macOS

This is the big one, and it is not fixable at the tap level.

QEMU only compiles its SPICE OpenGL support when both `CONFIG_OPENGL` and
`CONFIG_GBM` are set. From `include/ui/spice-display.h`:

```c
#if defined(CONFIG_OPENGL) && defined(CONFIG_GBM)
#  define HAVE_SPICE_GL 1
#  include "ui/egl-helpers.h"
#  include "ui/egl-context.h"
#endif
```

GBM (Generic Buffer Management) is part of Mesa and depends on Linux DRM. There
is no macOS implementation, so `HAVE_SPICE_GL` is never defined in a macOS
build. The `gl` and `rendernode` options are compiled out of `-spice` entirely
(`ui/spice-core.c` wraps them in `#ifdef HAVE_SPICE_GL`).

QEMU's own `meson.build` shows the same requirement for the related vhost-user
GPU path:

```meson
have_vhost_user_gpu = have_vhost_user_gpu and virgl.found() and opengl.found() and gbm.found()
```

What this looks like in practice, on a build configured with
`--enable-opengl --enable-virglrenderer` against a working virglrenderer:

| Attempt | Result |
|---|---|
| `-spice gl=on` | `Invalid parameter 'gl'` |
| `-display cocoa,gl=on` | `OpenGL is not supported by display backend 'cocoa'` |
| `-device virtio-gpu-gl` | `The display backend does not have OpenGL support enabled` |
| `-display egl-headless` | `egl: not available on this platform` |

`ui/cocoa.m` has no GL context handling at all — no `dpy_gl` hooks, no
`DisplayGLMode` support. The `gl` suboption parses on `-display cocoa` only
because `gl` is declared on the shared `DisplayOptions` base in `qapi/ui.json`;
`system/vl.c` then rejects it at runtime:

```c
if (dpy.has_gl && dpy.gl != DISPLAY_GL_MODE_OFF && display_opengl == 0) {
    error_report("OpenGL is not supported by display backend '%s'", ...);
```

### Why the virglrenderer and libepoxy-egl formulas were removed

Version 1.x of this tap built two extra formulas to try to enable the above:

- `libepoxy-egl` — libepoxy 1.5.10 with a three-hunk patch enabling EGL on
  Darwin
- `virglrenderer` — akihikodaki's `macos` branch fork

Neither could have any effect, for the reason above: without GBM, QEMU never
compiles the code that would call into them. They also had problems of their
own:

- The `virglrenderer` formula pinned revision `0a26988c5c4f3009c5b68e83dc0e36fb50e8c4f5`,
  which is not present in `akihikodaki/virglrenderer`. Fetching it fails with
  `upload-pack: not our ref`, so a clean install of the tap could not complete.
  That fork's `macos` branch has had no commits since 2023-12-10.
- `libepoxy-egl` conflicted with homebrew-core's `libepoxy`, which several other
  formulas depend on.
- Two of its three patch hunks are now upstream anyway
  ([anholt/libepoxy#239](https://github.com/anholt/libepoxy/pull/239) and
  [#314](https://github.com/anholt/libepoxy/pull/314), merged March 2026),
  and the third was already dead code because the formula passed `-Degl=yes`,
  which bypasses the `auto` detection branch the patch modified.

**If you need a GPU-accelerated VM on Apple Silicon**, use
[UTM](https://mac.getutm.app/) with the Apple Virtualization backend, or
Virtualization.framework directly. QEMU on macOS is the wrong tool for that job.

## HVF only accelerates same-architecture guests

Hypervisor.framework virtualises the CPU you already have. It cannot accelerate
a foreign architecture.

On Apple Silicon:

```console
$ qemu-system-x86_64 -M q35 -accel hvf -m 128M
qemu-system-x86_64: -accel hvf: invalid accelerator hvf
```

```console
$ qemu-system-aarch64 -M virt -accel hvf -cpu host -m 128M    # works
```

x86_64 guests on Apple Silicon fall back to TCG (`-accel tcg`) and run at
emulation speed, which is roughly an order of magnitude slower than native. If
you need x86_64 performance on Apple Silicon, QEMU is not going to provide it.

Earlier versions of this tap shipped a `qemu-spice-vm` wrapper that ran
`qemu-system-x86_64 ... accel=hvf` and a README claiming "x86_64 guests: ~80% of
bare metal with HVF". Both were wrong; the wrapper failed immediately on the
hardware it was written for.

## Conflicts with homebrew-core qemu

`qemu-spice` and `qemu` both install `qemu-system-*`, `qemu-img` and friends, so
they cannot both be linked. The formula declares `conflicts_with "qemu"`.

```bash
brew unlink qemu                       # keep core qemu installed but unlinked
brew install stuffbucket/qemu-spice/qemu-spice
```

To switch back:

```bash
brew uninstall qemu-spice && brew link qemu
```

## No bottles

This tap builds from source every time — around 10–20 minutes for the six
targets it configures. Homebrew caches the downloaded QEMU tarball in
`~/Library/Caches/Homebrew/downloads`, so rebuilds skip the download but still
recompile.

The formula builds `aarch64`, `arm`, `i386`, `riscv32`, `riscv64` and `x86_64`
rather than core's full target list, specifically to keep this bearable. If you
need another target, add it to `TARGETS` in `Formula/qemu-spice.rb` and
reinstall.

## SPICE without a password is unauthenticated

`disable-ticketing=on` disables authentication entirely. Anyone who can reach
the port gets full console access to the VM, including keyboard and mouse.

Bind to localhost:

```bash
-spice addr=127.0.0.1,port=5900,disable-ticketing=on
```

or set a password via a secret object rather than exposing an open port:

```bash
-object secret,id=sec0,data=yourpassword \
-spice addr=127.0.0.1,port=5900,password-secret=sec0
```

For access across a network, tunnel over SSH rather than exposing SPICE
directly:

```bash
ssh -N -L 5900:127.0.0.1:5900 user@vmhost
spicy -h 127.0.0.1 -p 5900
```

## Clipboard and resolution require a guest agent

The vdagent channel on the host side only provides the transport:

```bash
-device virtio-serial-pci \
-chardev spicevmc,id=vdagent,name=vdagent \
-device virtserialport,chardev=vdagent,name=com.redhat.spice.0
```

Clipboard sharing and dynamic resolution need `spice-vdagent` running **inside
the guest**. On Debian/Ubuntu guests: `apt install spice-vdagent`. On Fedora:
`dnf install spice-vdagent`.

## Reporting a problem

Include the output of:

```bash
make status
make sync-check
qemu-system-aarch64 --version
brew config
```
