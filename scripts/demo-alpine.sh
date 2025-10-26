#!/bin/bash
# Demo script: Boot Alpine Linux with GPU acceleration
# Demonstrates QEMU-SPICE working with native macOS display

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}QEMU-SPICE Demo: Alpine Linux${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Configuration
CACHE_DIR="$HOME/.cache/qemu-spice"
ALPINE_VERSION="3.20.3"
ALPINE_ARCH="aarch64"
ALPINE_ISO="alpine-virt-${ALPINE_VERSION}-${ALPINE_ARCH}.iso"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/${ALPINE_ARCH}/${ALPINE_ISO}"
ISO_PATH="$CACHE_DIR/$ALPINE_ISO"

# Create cache directory
mkdir -p "$CACHE_DIR"

# Download Alpine if not cached
if [ ! -f "$ISO_PATH" ]; then
    echo -e "${YELLOW}Downloading Alpine Linux...${NC}"
    echo "URL: $ALPINE_URL"
    echo "Size: ~100MB"
    echo ""
    if command -v curl &> /dev/null; then
        curl -L -o "$ISO_PATH" "$ALPINE_URL"
    elif command -v wget &> /dev/null; then
        wget -O "$ISO_PATH" "$ALPINE_URL"
    else
        echo -e "${RED}Error: curl or wget required to download Alpine${NC}"
        exit 1
    fi
    echo ""
else
    echo -e "${GREEN}✓${NC} Using cached Alpine ISO: $ISO_PATH"
    echo ""
fi

# Check if running on Apple Silicon
if [[ $(uname -m) == "arm64" ]]; then
    QEMU_BIN="qemu-system-aarch64"
    MACHINE_ARGS="-machine virt,accel=hvf -cpu host"
    GPU_DEVICE="virtio-gpu-pci"
    DISPLAY_ARGS="-display cocoa,show-cursor=on"
    # Need UEFI firmware for ARM to boot Alpine
    BIOS_ARGS="-bios /opt/homebrew/Cellar/qemu-spice/10.1.2/share/qemu/edk2-aarch64-code.fd"
    echo -e "${GREEN}✓${NC} Running on Apple Silicon - using HVF acceleration"
else
    QEMU_BIN="qemu-system-x86_64"
    MACHINE_ARGS="-machine q35,accel=tcg"
    GPU_DEVICE="virtio-vga"
    DISPLAY_ARGS="-display cocoa,show-cursor=on"
    BIOS_ARGS=""
    echo -e "${YELLOW}⚠${NC}  Running on Intel - using TCG emulation (slower)"
fi

echo ""
echo -e "${BLUE}Starting Alpine Linux...${NC}"
echo ""
echo "Configuration:"
echo "  - CPU: 2 cores (host passthrough with HVF)"
echo "  - RAM: 1GB"
echo "  - GPU: $GPU_DEVICE (VirtIO display)"
echo "  - Display: Cocoa (native macOS)"
echo "  - Boot: Alpine Linux $ALPINE_VERSION live ISO"
echo ""
echo -e "${YELLOW}Note:${NC} This is a live boot (no persistence)"
echo -e "${YELLOW}Login:${NC} root (no password)"
echo -e "${YELLOW}Note:${NC} Cocoa display doesn't support GL; use spice-app for GL demos"
echo ""
echo "Press Ctrl+Q or close the window to exit QEMU"
echo "Boot messages will appear in this terminal and the GUI window"
echo ""
read -p "Press Enter to start..." -r
echo ""

# Launch QEMU with Alpine
# Note: Serial console shows boot progress in terminal while GUI shows graphical output
$QEMU_BIN \
    $MACHINE_ARGS \
    $BIOS_ARGS \
    -smp 2 \
    -m 1G \
    -device $GPU_DEVICE \
    $DISPLAY_ARGS \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -audio coreaudio \
    -device intel-hda \
    -device hda-duplex \
    -device virtio-rng-pci \
    -device virtio-serial-pci \
    -device virtio-keyboard-pci \
    -device virtio-mouse-pci \
    -serial stdio \
    -cdrom "$ISO_PATH" \
    -boot d
