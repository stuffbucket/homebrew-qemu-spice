# Known Issues and Workarounds

This document covers known issues, limitations, and workarounds for QEMU with SPICE support on Apple Silicon macOS.

## Table of Contents

- [Critical Issues](#critical-issues)
- [Formula-Specific Issues](#formula-specific-issues)
- [QEMU Issues](#qemu-issues)
- [SPICE Issues](#spice-issues)
- [Platform Limitations](#platform-limitations)
- [Workarounds](#workarounds)

---

## Critical Issues

###  1. libepoxy-egl Patch Dependency

**Issue**: Our `libepoxy-egl` formula uses external patches that may break if upstream changes.

**Affected Files**:
- `Formula/libepoxy-egl.rb:17-18` - External patch from GitHub PR#239

**Patch URL**:
```ruby
url "https://github.com/anholt/libepoxy/pull/239.patch"
sha256 "e88d7fc5c384f93a5c4659c5fc1ac9e5e3d5bb964d5d54bdb97e4e46c1c9b1d4"
```

**Risk**:
- Medium - If the PR is merged or deleted, the URL may become invalid
- EGL support on macOS is not officially supported by libepoxy

**Workaround**:
- We maintain an inline patch (`:DATA`) as a backup
- Consider hosting the patch in this repository if the external URL breaks

**Long-term Solution**:
```bash
# If external patch fails, copy it locally:
# 1. Download the patch: curl -o patches/libepoxy-egl-239.patch https://...
# 2. Update formula to use local patch:
patch do
  url "file://#{buildpath}/../patches/libepoxy-egl-239.patch"
end
```

###  2. virglrenderer macOS Fork Dependency

**Issue**: Using akihikodaki's macOS fork instead of official virglrenderer.

**Affected Files**:
- `Formula/virglrenderer.rb:7-10` - GitHub fork with macOS branch

**Current**:
```ruby
url "https://github.com/akihikodaki/virglrenderer.git",
    branch: "macos",
    revision: "0a26988c5c4f3009c5b68e83dc0e36fb50e8c4f5"
```

**Risk**:
- Medium - Fork may not receive upstream updates
- Specific commit pinning prevents automatic updates

**Status**:
- This is intentional - official virglrenderer doesn't support macOS
- Fork is actively maintained for UTM project

**Monitoring**:
```bash
# Check for updates periodically:
git ls-remote https://github.com/akihikodaki/virglrenderer.git macos
```

###  3. Conflicts with Standard Homebrew Packages

**Issue**: Our custom packages conflict with standard Homebrew versions.

**Conflicts**:
- `libepoxy-egl` conflicts with `libepoxy`
- `qemu-spice` may conflict with `qemu`

**Impact**:
- Users with existing `qemu` or `libepoxy` installations must unlink them
- Can't have both versions installed simultaneously

**Documented In**: INSTALL.md

**Workaround**:
```bash
# Before installing:
brew unlink qemu libepoxy 2>/dev/null || true

# To revert:
brew uninstall qemu-spice libepoxy-egl
brew install qemu libepoxy
```

---

## Formula-Specific Issues

###  1. Build Time Dependencies

**Issue**: Building from source takes 30-45 minutes on Apple Silicon.

**Why**:
- QEMU is a large codebase (~700MB source)
- Compiling for 6 target architectures
- No bottles (pre-compiled binaries) available

**Impact**: Long initial installation time

**Workaround**:
- None - this is expected for source builds
- Consider creating bottles for faster installation:
  ```bash
  brew install --build-bottle ./Formula/qemu-spice.rb
  brew bottle qemu-spice
  ```

###  2. HEAD-only Builds Required

**Issue**: `libepoxy-egl` and `virglrenderer` require `--HEAD` flag.

**Why**:
- Building from Git repositories instead of release tarballs
- macOS support not in official releases

**Commands**:
```bash
brew install --HEAD ./Formula/libepoxy-egl.rb
brew install --HEAD ./Formula/virglrenderer.rb
```

**Impact**:
- Updates require `brew reinstall --HEAD`
- No version pinning available

**Workaround**: Pin to specific Git revisions (already done in virglrenderer formula)

---

## QEMU Issues

### - 1. QEMU Audio Issues (RESOLVED)

**Status**: - **RESOLVED** in QEMU 10.1.2

**Previous Issue**: QEMU 9.1.1 had an audio regression causing crackling/stuttering.

**Current Status**: We now use QEMU 10.1.2 (latest stable as of October 2025) which includes all audio fixes.

**If you still experience audio issues**:
```bash
# Try increasing buffer size:
-audiodev coreaudio,id=audio0,out.buffer-length=10000

# Or use AC97 instead of Intel HDA:
-device ac97,audiodev=audio0
```

###  2. HVF Acceleration Architecture Limitation

**Issue**: HVF only accelerates guests matching host architecture.

**Platform**: macOS Hypervisor.framework limitation

**Impact**:
- - ARM64 guests on ARM64 host: ~95% native performance (accelerated)
-  x86_64 guests on ARM64 host: ~20-80% performance (emulated with some optimization)
-  x86_64 guests cannot use full HVF acceleration on Apple Silicon

**Clarification**:
- QEMU 9.x DOES support HVF for x86_64 guests on ARM64 hosts
- Performance is still good (~80% for many workloads) but not native

**Recommendation**: Use ARM64 guests when possible for best performance.

###  3. Guest Agent Not Built

**Issue**: Our formula disables QEMU guest agent (`--disable-guest-agent`).

**Why**:
- Simplifies build
- Guest agents are installed inside VMs, not on host
- Follows standard Homebrew qemu formula

**Impact**: No host-side guest agent binary (not needed for typical use)

**Workaround**: Install guest agent inside VMs (see GUEST-TOOLS.md)
```bash
# Inside Linux guest:
sudo apt install qemu-guest-agent
```

---

## SPICE Issues

###  1. SPICE Remote Viewer Connection Issues

**Issue**: `remote-viewer` may fail to connect with "Unable to connect to graphic server" error.

**Source**: Multiple user reports (2024-2025)

**Symptoms**:
```
ERROR: Unable to connect to the graphic server
runtime check failure in virt-viewer
```

**Causes**:
- SPICE port not accessible
- Firewall blocking connection
- SPICE agent not running in guest

**Workarounds**:

**a) Check SPICE is listening:**
```bash
# On host, verify QEMU is listening:
lsof -i :5900
netstat -an | grep 5900
```

**b) Use correct remote-viewer path:**
```bash
# Apple Silicon:
/opt/homebrew/bin/remote-viewer spice://localhost:5900

# Intel:
/usr/local/bin/remote-viewer spice://localhost:5900
```

**c) Rebuild spice-gtk from source:**
```bash
brew reinstall --build-from-source spice-gtk
```

**d) Try alternative connection:**
```bash
# If localhost doesn't work, try 127.0.0.1:
remote-viewer spice://127.0.0.1:5900
```

###  2. SPICE Guest Agent Clipboard Issues

**Issue**: Clipboard sharing not working between host and guest.

**Cause**: Guest agent not installed or not running

**Solution**: See GUEST-TOOLS.md

**Verify in guest:**
```bash
# Linux:
systemctl status spice-vdagent

# Check virtio-serial device exists:
ls -la /dev/virtio-ports/
# Should see: com.redhat.spice.0

# Restart if needed:
sudo systemctl restart spice-vdagent
```

**Windows**:
- Install SPICE guest tools from https://www.spice-space.org/download.html
- Check "SPICE Agent" service is running

###  3. SPICE Default Enablement in virt-manager

**Issue**: virt-manager assumes SPICE support and enables it by default (macOS doesn't support this out of the box).

**Impact**: New VMs fail to start with SPICE errors

**Workaround**: Remove SPICE settings when using virt-manager on macOS, use Cocoa display instead:
```xml
<!-- In VM XML, use: -->
<graphics type='cocoa'/>
<!-- Instead of: -->
<graphics type='spice'/>
```

---

## Platform Limitations

###  1. macOS OpenGL Deprecation

**Issue**: Apple deprecated OpenGL on macOS in favor of Metal.

**Impact**:
- OpenGL still works but won't receive updates
- May have bugs that won't be fixed
- virglrenderer relies on OpenGL

**Current Status**: Still functional on macOS 15 (Sequoia)

**Future Risk**: Apple may remove OpenGL entirely in future macOS versions

**Long-term**:
- Metal backend for virglrenderer (in development)
- ANGLE (OpenGL ES → Metal) as workaround (our approach with libepoxy)

###  2. EGL Not Officially Supported on macOS

**Issue**: EGL (OpenGL rendering to offscreen surfaces) is not natively supported on macOS.

**Our Approach**: Patch libepoxy to enable EGL via ANGLE

**Risk**:
- Patches may break with macOS updates
- Performance may be suboptimal compared to native implementations

**Status**: Currently working, but monitor for macOS updates

###  3. No Native SPICE on macOS

**Issue**: SPICE protocol was designed for Linux/Windows, not macOS.

**Why We Build It Anyway**:
- Works for VMs running on macOS (host support)
- Enables remote access to Linux/Windows VMs
- Better than VNC for features like clipboard, USB redirect

**Limitation**: Can't use SPICE to connect TO a macOS guest (use Screen Sharing instead)

---

## Workarounds

### USB Passthrough Permissions

**Issue**: USB passthrough may fail with permission errors.

**Solution**:
```bash
# Find USB device:
system_profiler SPUSBDataType

# QEMU needs permission to access USB
# Temporary (until reboot):
sudo chmod 666 /dev/bus/usb/*/***

# Or run QEMU with sudo (not recommended for production):
sudo qemu-system-x86_64 -device usb-host,vendorid=0x1234,productid=0x5678 ...
```

**Better Solution**: Create udev rules (on Linux) or use dedicated user permissions

### Display Issues with Cocoa

**Issue**: Cocoa display may have scaling issues on Retina displays.

**Workaround**:
```bash
# Try different scaling:
-display cocoa,gl=on,show-cursor=on

# Or disable OpenGL:
-display cocoa,gl=off
```

### Network Not Working in Guest

**Issue**: User-mode networking doesn't work.

**Causes**:
- Missing virtio-net driver in guest
- Firewall blocking

**Solutions**:
```bash
# a) Verify virtio-net device is present:
-device virtio-net-pci,netdev=net0

# b) Install virtio drivers in guest (Windows):
# Load NetKVM driver from virtio-win.iso

# c) Use different NIC model:
-device e1000,netdev=net0  # More compatible, slower

# d) Add DNS forwarding:
-netdev user,id=net0,dns=8.8.8.8
```

### High CPU Usage

**Issue**: QEMU using 100%+ CPU even when guest is idle.

**Causes**:
- No HVF acceleration
- Incorrect CPU topology
- Missing idle support

**Solutions**:
```bash
# a) Verify HVF is enabled:
qemu-system-x86_64 -accel help | grep hvf
# Add: -accel hvf

# b) Don't oversubscribe CPUs:
# Check your CPU count first: sysctl hw.ncpu
# Leave 25-30% for macOS:
-smp cpus=8,cores=8,threads=1  # Adjust to your system

# c) Enable CPU idle:
-cpu host,+idle
```

---

## Testing for Issues

### Verify Installation

Run the provided verification script:
```bash
./scripts/verify-installation.sh
```

### Test HVF Acceleration

```bash
# Should show "hvf":
qemu-system-x86_64 -accel help | grep hvf

# Should NOT show error:
qemu-system-aarch64 -M virt,accel=hvf -cpu host -m 1G -nographic -kernel /dev/null
# (Will fail on missing kernel, but HVF should initialize)
```

### Test SPICE Support

```bash
# Should show SPICE devices:
qemu-system-x86_64 -device help | grep -i spice

# Expected output includes:
# name "qxl", bus PCI, desc "Spice QXL GPU (secondary)"
# name "qxl-vga", bus PCI, desc "Spice QXL GPU (primary, vga compatible)"
```

### Test Audio

```bash
# Should show "coreaudio":
qemu-system-x86_64 -audiodev help

# Test audio device:
qemu-system-x86_64 -audiodev coreaudio,id=audio0 -device intel-hda \
  -device hda-duplex,audiodev=audio0 -m 1G -nographic
```

---

## Reporting Issues

### Before Reporting

1. Check this document for known issues
2. Run `./scripts/verify-installation.sh`
3. Review relevant logs:
   ```bash
   # Homebrew build logs:
   brew log qemu-spice

   # QEMU output:
   # Add -D /tmp/qemu.log to your command

   # SPICE logs:
   # Add SPICE_DEBUG=1 environment variable
   ```

### Information to Include

When reporting issues, include:

1. **System Information**:
   ```bash
   sw_vers  # macOS version
   uname -m  # Architecture
   sysctl hw.model hw.ncpu hw.memsize  # Hardware
   ```

2. **QEMU Version**:
   ```bash
   qemu-system-x86_64 --version
   brew list --versions qemu-spice
   ```

3. **Complete Command**:
   - Full QEMU command line used
   - Any error messages
   - Expected vs actual behavior

4. **Guest Details**:
   - Guest OS and version
   - Guest tools installed (yes/no)

### Where to Report

- **Formula issues**: This repository (when published)
- **QEMU bugs**: https://gitlab.com/qemu-project/qemu/-/issues
- **SPICE bugs**: https://gitlab.freedesktop.org/spice/spice/-/issues
- **macOS-specific**: Reference UTM project or homebrew discussions

---

## Monitoring for Updates

### Upstream Projects to Watch

1. **QEMU**: https://www.qemu.org/
   - Watch for 9.1.2+ releases (fixes audio regression)

2. **SPICE**: https://www.spice-space.org/
   - Monitor macOS compatibility improvements

3. **virglrenderer**: https://gitlab.freedesktop.org/virgl/virglrenderer
   - Check for official macOS support

4. **libepoxy**: https://github.com/anholt/libepoxy
   - Watch PR #239 and related EGL patches

### Regular Maintenance

```bash
# Check for QEMU updates:
curl -s https://www.qemu.org/ | grep "QEMU.*released"

# Check virglrenderer fork:
git ls-remote https://github.com/akihikodaki/virglrenderer.git macos

# Update formula versions as needed
```

---

## Summary

### Important (Be Aware)

-  Long build times (30-45 minutes)
-  Conflicts with standard Homebrew packages
-  SPICE remote-viewer connection issues reported

### Monitoring (Watch for Changes)

-  macOS OpenGL deprecation
-  Upstream virglrenderer macOS support
-  QEMU HVF improvements

### Working As Expected

- HVF acceleration (different performance for ARM64 vs x86_64 guests)
- SPICE protocol (with workarounds)
- Audio passthrough (with CoreAudio)
- USB passthrough (with permissions)

---

**Last Updated**: October 25, 2025
**Formula Version**: 1.0.0
**QEMU Version**: 10.1.2 (latest stable)

See also: [VERSIONS.md](VERSIONS.md) for detailed version information
