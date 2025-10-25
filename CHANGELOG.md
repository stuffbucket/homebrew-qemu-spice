# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-10-25

### Initial Release

Homebrew tap providing QEMU 10.1.2 with SPICE protocol support, optimized for Apple Silicon.

#### Formulas

- **qemu-spice** - QEMU 10.1.2 with SPICE support and Apple Silicon optimizations
- **spice-server** - SPICE server library 0.15.2 (last macOS-compatible version)
- **virglrenderer** - Virtual GPU renderer using akihikodaki's macOS fork
- **libepoxy-egl** - OpenGL function pointer library 1.5.10 with EGL patches for macOS

#### Features

- QEMU 10.1.2 (latest stable as of October 2025)
- SPICE protocol support with GPU acceleration
- Apple Silicon ARM64 optimizations (`-march=armv8.5-a`)
- HVF (Hypervisor.framework) acceleration
- GPU acceleration via virglrenderer with OpenGL/EGL
- CoreAudio passthrough with Intel HDA
- USB device passthrough
- VirtIO paravirtualized devices

#### Supported Architectures

- aarch64-softmmu (ARM 64-bit)
- x86_64-softmmu (Intel/AMD 64-bit)
- arm-softmmu (ARM 32-bit)
- i386-softmmu (Intel 32-bit)
- riscv64-softmmu (RISC-V 64-bit)
- riscv32-softmmu (RISC-V 32-bit)

#### Performance

- ARM64 guests: ~95% of bare metal with HVF
- x86_64 guests: ~80% of bare metal with HVF

#### Documentation

- README.md - Main documentation
- docs/INSTALL.md - Installation guide and troubleshooting
- docs/KNOWN-ISSUES.md - Known issues and workarounds
- CHANGELOG.md - Version history

#### Credits

Based on [avoidik/homebrew-qemu-spice](https://github.com/avoidik/homebrew-qemu-spice) with enhancements for Apple Silicon.
