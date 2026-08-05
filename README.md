# homebrew-qemu-spice

QEMU with SPICE remote-display support for macOS.

This tap ships **one formula**: `qemu-spice`, which is homebrew-core's `qemu`
formula with SPICE enabled. Nothing else is patched, forked, or pinned.

## Why this tap exists

Homebrew-core deliberately does not ship QEMU with SPICE. It was enabled in
[Homebrew/homebrew-core#226935](https://github.com/Homebrew/homebrew-core/pull/226935)
and reverted a week later by
[#227722](https://github.com/Homebrew/homebrew-core/pull/227722) with the reason
*"Too many dependencies"* — `spice-server` pulls in `gstreamer`, `opus`, `orc`
and `openssl@3`, which core did not want in every QEMU install.

So `brew install qemu` gives you a QEMU that rejects `-spice` as an invalid
option. If you want SPICE you need a build configured with `--enable-spice`.
That is the entire purpose of this tap.

If homebrew-core ever adds `spice-server` back, this tap becomes unnecessary —
`make sync-check` detects that case and tells you.

## Requirements

- macOS (Apple Silicon or Intel)
- Xcode Command Line Tools — `xcode-select --install`
- [Homebrew](https://brew.sh)

## Installation

```bash
brew tap stuffbucket/qemu-spice
brew install --build-from-source stuffbucket/qemu-spice/qemu-spice
```

This tap publishes no bottles, so it always builds from source. Expect roughly
10–20 minutes.

`qemu-spice` conflicts with core `qemu` — both install `qemu-system-*` binaries.
If you already have core qemu installed:

```bash
brew unlink qemu
```

To go back to core qemu later:

```bash
brew uninstall qemu-spice && brew link qemu
```

## Quick start

Create a disk and boot an ARM64 Linux ISO with a SPICE server attached. On
Apple Silicon this is the fast path — HVF accelerates aarch64 guests natively.

```bash
mkdir -p ~/VMs && cd ~/VMs
qemu-img create -f qcow2 linux-arm64.qcow2 40G

qemu-system-aarch64 \
  -M virt,accel=hvf,highmem=on -cpu host -smp 4 -m 8G \
  -bios /opt/homebrew/share/qemu/edk2-aarch64-code.fd \
  -device virtio-gpu-pci \
  -display none \
  -spice addr=127.0.0.1,port=5900,disable-ticketing=on \
  -device virtio-serial-pci \
  -chardev spicevmc,id=vdagent,name=vdagent \
  -device virtserialport,chardev=vdagent,name=com.redhat.spice.0 \
  -audiodev coreaudio,id=audio0 \
  -device intel-hda -device hda-duplex,audiodev=audio0 \
  -device qemu-xhci,id=xhci -device usb-tablet \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-rng-pci \
  -drive file=linux-arm64.qcow2,if=virtio \
  -cdrom your-distro-arm64.iso
```

Connect a client:

```bash
brew install spice-gtk
spicy -h 127.0.0.1 -p 5900
```

`spice-gtk` is the SPICE client library and ships the `spicy` viewer. Note that
`virt-viewer` / `remote-viewer` is **not** packaged for macOS in Homebrew —
there is no `virt-viewer` formula or cask. If you prefer `remote-viewer`, run it
from a Linux box and point it at the host, or use [UTM](https://mac.getutm.app/),
which bundles its own SPICE client.

`disable-ticketing=on` means no password. It is bound to `127.0.0.1` above so
it is not reachable from the network. If you need remote access, set a password
rather than exposing an unauthenticated port.

Install `spice-vdagent` inside the guest to get clipboard sharing and automatic
resolution changes through the vdagent channel configured above.

### USB redirection over SPICE

`--enable-usb-redir` is compiled in:

```bash
  -device qemu-xhci,id=xhci \
  -chardev spicevmc,name=usbredir,id=usbredir1 \
  -device usb-redir,chardev=usbredir1,bus=xhci.0
```

Then pick the device in your SPICE client's USB device selection dialog.

See [docs/SPICE-OPTIONS.md](docs/SPICE-OPTIONS.md) for the full option
reference.

## What this does not do

**There is no GPU acceleration, and there cannot be on macOS.** QEMU's SPICE GL
path is gated on `HAVE_SPICE_GL`, which requires `CONFIG_OPENGL && CONFIG_GBM`
(see `include/ui/spice-display.h`). GBM is a Mesa/DRM component that does not
exist on macOS. Concretely, on any macOS QEMU build:

| Attempt | Result |
|---|---|
| `-spice gl=on` | `Invalid parameter 'gl'` — the option is not even registered |
| `-display cocoa,gl=on` | `OpenGL is not supported by display backend 'cocoa'` |
| `-device virtio-gpu-gl` | `The display backend does not have OpenGL support enabled` |
| `-display egl-headless` | `egl: not available on this platform` |

Earlier versions of this tap built patched `libepoxy-egl` and `virglrenderer`
formulas to chase this. They could not work and have been removed. See
[docs/KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md).

**HVF only accelerates a guest whose architecture matches the host.** On Apple
Silicon `qemu-system-aarch64 -accel hvf` is fast; `qemu-system-x86_64 -accel
hvf` fails outright with `invalid accelerator hvf`. x86_64 guests on Apple
Silicon run under TCG emulation and are slow.

If you want a GPU-accelerated VM on Apple Silicon, use
[UTM](https://mac.getutm.app/) or Virtualization.framework instead of QEMU.

## Included targets

The formula builds six system targets rather than core's full set, because this
tap has no bottles and every install compiles from source:

`aarch64` · `arm` · `i386` · `riscv32` · `riscv64` · `x86_64`

## Staying current with homebrew-core

The formula is homebrew-core's `qemu` with the SPICE changes confined to blocks
marked `SPICE divergence`. To check whether core has moved:

```bash
make sync-check
```

It compares version, sha256, dependencies and configure arguments against
core's live formula, ignores the intentional SPICE differences, and exits
non-zero on drift. CI runs it weekly and opens the report in the job log.

When it reports drift, copy the changed lines from
[core's qemu.rb](https://github.com/Homebrew/homebrew-core/blob/master/Formula/q/qemu.rb)
into `Formula/qemu-spice.rb`, leaving the `SPICE divergence` blocks alone.

## Development

```bash
make help          # list targets
make sync-check    # drift vs homebrew-core
make style         # brew style
make audit         # brew style + brew audit --strict
make install       # build from source
make test          # formula tests + SPICE smoke checks
make verify        # full verification script
make status        # what is installed and linked
```

## Documentation

- [docs/INSTALL.md](docs/INSTALL.md) — installation and troubleshooting
- [docs/SPICE-OPTIONS.md](docs/SPICE-OPTIONS.md) — SPICE option reference
- [docs/KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md) — limitations, including the GL story
- [CHANGELOG.md](CHANGELOG.md) — version history

## Credits

Originally based on [avoidik/homebrew-qemu-spice](https://github.com/avoidik/homebrew-qemu-spice).
The formula now tracks [homebrew-core's qemu](https://github.com/Homebrew/homebrew-core/blob/master/Formula/q/qemu.rb)
directly.

## License

See [LICENSE](LICENSE). QEMU itself is GPL-2.0-only.
