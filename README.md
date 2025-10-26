# homebrew-qemu-spice

QEMU 10.1.2 with SPICE protocol support for Apple Silicon macOS.

## Features

- QEMU 10.1.2 with SPICE protocol support
- Apple Silicon ARM64 optimizations (`-march=armv8.5-a`)
- HVF (Hypervisor.framework) acceleration
- GPU acceleration via virglrenderer
- CoreAudio passthrough with Intel HDA
- USB device passthrough
- VirtIO paravirtualized devices

## Installation

### Using Homebrew Tap (Recommended)

Now that the formulas are published on GitHub, this is the easiest way:

```bash
# Unlink existing QEMU if installed
brew unlink qemu 2>/dev/null || true

# Add the tap
brew tap stuffbucket/qemu-spice

# Install dependencies
brew install --HEAD stuffbucket/qemu-spice/libepoxy-egl
brew install --HEAD stuffbucket/qemu-spice/virglrenderer
brew install spice-server  # From Homebrew core

# Install QEMU with SPICE
brew install stuffbucket/qemu-spice/qemu-spice
```

**Build time:** 30-45 minutes on Apple Silicon.

### For Development: Using Makefile

If you're developing or contributing to the formulas:

```bash
# Clone the repository
git clone https://github.com/stuffbucket/homebrew-qemu-spice.git
cd homebrew-qemu-spice

# Check what's available
make help

# Build everything (handles dependencies automatically)
make build

# Or build step-by-step
make check-deps
make libepoxy-egl
make virglrenderer
make spice-server
make qemu-spice

# Run tests
make test

# Check installation status
make status
```

## Download Caching

Homebrew automatically caches downloaded sources in `~/Library/Caches/Homebrew/downloads`. This means:

- **First build:** Downloads all sources (~200MB for QEMU alone)
- **Rebuilds:** Reuses cached files, only rebuilds changed code
- **Clean cache:** `make clean-downloads` (or `brew cleanup -s`)
- **Check cache:** `make show-cache`

The Makefile leverages this caching automatically, making rebuilds much faster.

## Quick Start

### ARM64 Linux VM (Best Performance)

```bash
# Create VM directory
mkdir -p ~/VMs && cd ~/VMs

# Create disk
qemu-img create -f qcow2 ubuntu-arm64.qcow2 80G

# Download Ubuntu ARM64
wget https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04-desktop-arm64.iso

# Start VM
qemu-system-aarch64 \
  -machine virt,accel=hvf,highmem=on \
  -cpu host -smp 8 -m 16G \
  -device virtio-gpu-gl-pci \
  -display cocoa,gl=on \
  -audiodev coreaudio,id=audio0 \
  -device intel-hda -device hda-duplex,audiodev=audio0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -drive file=ubuntu-arm64.qcow2,if=virtio \
  -cdrom ubuntu-24.04-desktop-arm64.iso
```

### x86_64 Linux VM

```bash
# Create disk
qemu-img create -f qcow2 ubuntu-x86_64.qcow2 80G

# Download Ubuntu x86_64
wget https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso

# Start VM
qemu-system-x86_64 \
  -machine q35,accel=hvf \
  -cpu host -smp 8 -m 16G \
  -device virtio-vga-gl \
  -display cocoa,gl=on \
  -spice port=5900,disable-ticketing=on,gl=on \
  -audiodev coreaudio,id=audio0 \
  -device intel-hda -device hda-duplex,audiodev=audio0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -drive file=ubuntu-x86_64.qcow2,if=virtio \
  -cdrom ubuntu-24.04-desktop-amd64.iso
```

## Performance

On Apple Silicon with HVF acceleration:

| Guest Architecture | Expected Performance |
|-------------------|---------------------|
| ARM64 (native) | ~95% of bare metal |
| x86_64 (emulated) | ~80% of bare metal |

## Components

### qemu-spice
QEMU 10.1.2 with SPICE support and Apple Silicon optimizations.

### spice-server
SPICE server library 0.16.0 (installed from Homebrew core).

### virglrenderer
Virtual GPU renderer using akihikodaki's macOS fork.

### libepoxy-egl
OpenGL function pointer library with EGL patches for macOS.

## Documentation

- [Installation Guide](docs/INSTALL.md) - Detailed installation and troubleshooting
- [Known Issues](docs/KNOWN-ISSUES.md) - Known issues and workarounds
- [Changelog](CHANGELOG.md) - Version history

## Differences from Standard Homebrew QEMU

| Feature | homebrew/core/qemu | This Tap |
|---------|-------------------|----------|
| SPICE protocol | No | Yes |
| virglrenderer | No | Yes |
| EGL/OpenGL on macOS | No | Yes |
| ARM64 optimizations | Basic | Advanced |
| Audio passthrough | Limited | CoreAudio + HDA |

## Common Operations

### SSH into VM

```bash
# With port forwarding (hostfwd=tcp::2222-:22)
ssh -p 2222 user@localhost
```

### Connect via SPICE

```bash
# Install viewer
brew install virt-viewer

# Connect
remote-viewer spice://localhost:5900
```

### USB Passthrough

```bash
# Find USB device
system_profiler SPUSBDataType

# Add to QEMU command
-device usb-host,vendorid=0x1234,productid=0x5678
```

## Resource Allocation

Leave 25-30% of CPU cores and RAM for macOS.

Example allocations:
- 8-core system: Use 4-6 cores, leave 2-4 for macOS
- 16-core system: Use 8-12 cores, leave 4-8 for macOS

Memory:
- Light workload: 8GB
- Development: 16GB
- Heavy workload: 24-32GB

## Troubleshooting

### QEMU not found

```bash
which qemu-system-x86_64
# Should be /opt/homebrew/bin/qemu-system-x86_64
```

### HVF not available

```bash
# Check HVF support
sysctl kern.hv_support
# Should return 1
```

### VM is slow

Ensure HVF acceleration is enabled:
```bash
qemu-system-x86_64 -accel help | grep hvf
# Should show "hvf"
```

## License

- Formulas: BSD-2-Clause (this repository)
- QEMU: GPL-2.0-only
- SPICE: LGPL-2.1-or-later
- virglrenderer: MIT
- libepoxy: MIT

See [LICENSE](LICENSE) for details.

## Credits

Based on [avoidik/homebrew-qemu-spice](https://github.com/avoidik/homebrew-qemu-spice) with enhancements for Apple Silicon.

Optimized by stuffbucket (2025).
