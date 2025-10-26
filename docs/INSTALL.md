# Installation Guide

Complete installation instructions for QEMU with SPICE support on Apple Silicon.

## System Requirements

- **macOS**: 12.0 (Monterey) or later
- **Hardware**: Apple Silicon Mac (ARM64)
- **RAM**: 16GB minimum, 32GB+ recommended for running VMs
- **Disk**: 10GB free space for QEMU + dependencies + VM images
- **Homebrew**: Latest version

## Installation Methods

### Method 1: GitHub Tap (Recommended)

Now that the formulas are published, this is the easiest method:

```bash
# 1. Unlink any existing QEMU installation
brew unlink qemu 2>/dev/null || true

# 2. Add the tap
brew tap stuffbucket/qemu-spice

# 3. Install dependencies in order
brew install --HEAD stuffbucket/qemu-spice/libepoxy-egl
brew install --HEAD stuffbucket/qemu-spice/virglrenderer
brew install spice-server  # From Homebrew core

# 4. Install QEMU with SPICE
brew install stuffbucket/qemu-spice/qemu-spice
```

### Method 2: Development with Makefile

For developers or contributors working on the formulas:

```bash
# Clone the repository
git clone https://github.com/stuffbucket/homebrew-qemu-spice.git
cd homebrew-qemu-spice

# Check available commands
make help

# Build everything (handles conflicts and dependencies automatically)
make build

# Verify installation
make verify
```

See `make help` for all available targets (test, status, clean-cache, etc.).

### Method 3: Alternative - Local Tap

If you want to share this tap or install on multiple machines:

```bash
# 1. Create a GitHub repository named "homebrew-qemu-spice"
# 2. Push this directory's contents to the repo
# 3. Install from the tap:

brew tap yourusername/qemu-spice
brew install --HEAD libepoxy-egl
brew install --HEAD virglrenderer
brew install spice-server  # From Homebrew core
brew install qemu-spice
```

## Build Time Expectations

On Apple Silicon Macs:
- **libepoxy-egl**: ~2-3 minutes
- **virglrenderer**: ~3-5 minutes
- **spice-server**: ~5-7 minutes
- **qemu-spice**: ~20-30 minutes

Total time: **30-45 minutes**

## Verification

After installation, verify everything works:

```bash
# Quick verification with Make
make verify

# Or run individual checks:
# Check QEMU version
qemu-system-x86_64 --version
qemu-system-aarch64 --version

# Check SPICE support
qemu-system-x86_64 -device help | grep spice
qemu-system-x86_64 -device help | grep virtio-vga-gl

# Check HVF (Hypervisor.framework) support
qemu-system-x86_64 -accel help | grep hvf

# Verify the convenience wrapper exists
which qemu-spice-vm
```

Expected output:
```
QEMU emulator version 10.1.2
...
name "qxl", bus PCI, desc "Spice QXL GPU (secondary)"
name "qxl-vga", bus PCI, desc "Spice QXL GPU (primary, vga compatible)"
name "virtio-vga-gl"
...
Accelerators supported in QEMU binary:
hvf
tcg
...
/opt/homebrew/bin/qemu-spice-vm
```

## Post-Installation Setup

### 1. Install SPICE Client (Optional)

For remote access to VMs:

```bash
brew install virt-viewer
```

### 2. Create a VMs Directory

```bash
mkdir -p ~/VMs
cd ~/VMs
```

### 3. Download a Test ISO

For ARM64 (native, best performance):
```bash
# Alpine Linux ARM64 (small, fast download)
wget https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/aarch64/alpine-virt-3.19.0-aarch64.iso
```

For x86_64 (good compatibility):
```bash
# Alpine Linux x86_64 (small, fast download)
wget https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-virt-3.19.0-x86_64.iso
```

### 4. Create Your First VM

```bash
# Create a 10GB disk
qemu-img create -f qcow2 ~/VMs/test.qcow2 10G

# Start the VM
qemu-spice-vm \
  -cdrom ~/VMs/alpine-virt-3.19.0-x86_64.iso \
  -hda ~/VMs/test.qcow2 \
  -boot d \
  -m 2G -smp 2
```

## Troubleshooting Installation

### Issue: Build fails with "unknown type name"

**Solution**: Make sure you have Xcode Command Line Tools installed:
```bash
xcode-select --install
```

### Issue: "cannot find -lepoxy" error

**Solution**: libepoxy-egl must be installed first:
```bash
brew install --HEAD ./Formula/libepoxy-egl.rb
```

### Issue: Meson/Ninja not found

**Solution**: Install build dependencies:
```bash
brew install meson ninja pkg-config
```

### Issue: SPICE-server fails to build

**Solution**: Check that spice-protocol is installed:
```bash
brew install spice-protocol
brew install ./Formula/spice-server.rb
```

### Issue: QEMU configure fails

**Solution**: Check the build logs:
```bash
# View logs for the most recent build
ls -lt $(brew --cache)/Logs/ | head -5

# Check specific formula logs
cat $(brew --cache)/Logs/qemu-spice/*.log | tail -100
```

Look for missing dependencies and install them.

### Issue: Conflicts with existing libepoxy

**Solution**: Unlink the standard libepoxy:
```bash
brew unlink libepoxy
brew install --HEAD ./Formula/libepoxy-egl.rb
```

### Issue: Python version errors

**Solution**: Ensure Python 3.12 is available:
```bash
brew install python@3.12
```

## Reinstallation

To reinstall from scratch:

**Using Makefile:**
```bash
# Uninstall and clean
make uninstall
make clean-cache

# Rebuild
make build
```

**Using Homebrew directly:**
```bash
# Uninstall everything
brew uninstall qemu-spice spice-server virglrenderer libepoxy-egl

# Clean up any cached builds
brew cleanup -s

# Reinstall
brew install --HEAD ./Formula/libepoxy-egl.rb
brew install --HEAD ./Formula/virglrenderer.rb
brew install ./Formula/spice-server.rb
brew install ./Formula/qemu-spice.rb
```

## Updating

When new versions are available:

```bash
# Update tap
brew update

# Reinstall with new versions
brew reinstall stuffbucket/qemu-spice/qemu-spice
```

Or manually update the version numbers in the formulas and reinstall.

## Uninstallation

Complete removal:

```bash
# Uninstall QEMU and dependencies
brew uninstall qemu-spice
brew uninstall spice-server
brew uninstall virglrenderer
brew uninstall libepoxy-egl

# Remove tap (if using one)
brew untap yourusername/qemu-spice

# Reinstall standard QEMU if desired
brew install qemu
```

## Advanced: Building Specific Targets

If you only want specific architectures:

Edit `qemu-spice.rb` and modify the target_list:

```ruby
target_list = %w[
  x86_64-softmmu
  # Remove others you don't need
]
```

This will reduce build time significantly.

## Next Steps

After successful installation:

1. Read the main [README.md](README.md) for usage examples
2. Check [EXAMPLES.md](EXAMPLES.md) for common VM configurations
3. Review [PERFORMANCE.md](PERFORMANCE.md) for optimization tips

## Getting Help

If you encounter issues:

1. Check the troubleshooting section above
2. Review build logs: `ls $(brew --cache)/Logs/`
3. Run verification: `make verify`
4. Check status: `make status`
5. Open an issue with:
   - Your macOS version: `sw_vers`
   - Your Mac model: `system_profiler SPHardwareDataType | grep "Model"`
   - Build logs from `$(brew --cache)/Logs/`
