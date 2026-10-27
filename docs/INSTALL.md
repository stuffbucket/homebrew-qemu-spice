# Installation

## Requirements

- macOS (Apple Silicon or Intel)
- Xcode Command Line Tools — `xcode-select --install`
- [Homebrew](https://brew.sh)
- ~5 GB free disk space for the build
- 10–20 minutes

## Install

```bash
brew tap stuffbucket/qemu-spice
brew install --build-from-source stuffbucket/qemu-spice/qemu-spice
```

Dependencies (`spice-server`, `usbredir`, `glib`, `pixman`, …) come from
homebrew-core and install as bottles. Only QEMU itself is compiled.

### If core qemu is already installed

`qemu-spice` conflicts with `qemu` — both provide `qemu-system-*`. Homebrew will
refuse to link them together:

```bash
brew unlink qemu
brew install --build-from-source stuffbucket/qemu-spice/qemu-spice
```

`brew unlink` keeps core qemu installed, just unlinked, so switching back is
cheap:

```bash
brew uninstall qemu-spice && brew link qemu
```

## Verify

```bash
make verify
```

or by hand:

```bash
qemu-system-aarch64 --version              # expect 11.1.2
qemu-system-aarch64 -spice help            # must list spice options
qemu-system-aarch64 -accel help            # must include hvf
```

The `-spice help` check is the one that matters. A QEMU without SPICE compiled
in responds:

```
qemu-system-aarch64: -spice: invalid option
```

Note that `-spice help` exits with status 1 even on success — it prints the
option list and then stops. Check the output, not the exit code.

## From a git clone

For working on the tap itself:

```bash
git clone https://github.com/stuffbucket/homebrew-qemu-spice.git
cd homebrew-qemu-spice

make help          # available targets
make sync-check    # drift vs homebrew-core
make style         # brew style
make install       # build from source
make test          # formula tests + smoke checks
```

To have Homebrew use your working copy directly instead of the published tap:

```bash
ln -sfn "$PWD" "$(brew --repository)/Library/Taps/stuffbucket/homebrew-qemu-spice"
```

## Troubleshooting

### `Error: qemu-spice: cannot install because conflicting formulae are installed`

Core qemu is linked. Run `brew unlink qemu`, then retry.

### `-spice: invalid option`

You are running core qemu, not this one. Check which binary is on PATH:

```bash
readlink -f "$(command -v qemu-system-aarch64)"
```

It should point into `Cellar/qemu-spice/...`. If it points at `Cellar/qemu/...`:

```bash
brew unlink qemu && brew link qemu-spice
```

### `invalid accelerator hvf`

You are trying to use HVF for a guest architecture that does not match the
host. HVF only accelerates same-architecture guests — on Apple Silicon that
means `qemu-system-aarch64`. Drop `-accel hvf` to fall back to TCG emulation,
which works for any architecture but is much slower. See
[KNOWN-ISSUES.md](KNOWN-ISSUES.md).

### `OpenGL is not supported by display backend 'cocoa'` / `Invalid parameter 'gl'`

There is no GL support in QEMU on macOS and there cannot be. Remove `gl=on`
from your `-display` and `-spice` options. See
[KNOWN-ISSUES.md](KNOWN-ISSUES.md) for the full explanation.

### Build fails

Homebrew keeps build logs:

```bash
ls -lt ~/Library/Caches/Homebrew/Logs/qemu-spice/
```

Check that the formula is current first:

```bash
make sync-check
```

If it reports drift, homebrew-core has moved and the formula needs updating —
that is the most common cause of a stale build breaking.

### Reclaiming space after a build

```bash
brew cleanup -s
```

## Uninstall

```bash
brew uninstall qemu-spice
brew untap stuffbucket/qemu-spice
brew link qemu              # if you want core qemu back
brew autoremove             # drop spice-server/usbredir if unused
```
