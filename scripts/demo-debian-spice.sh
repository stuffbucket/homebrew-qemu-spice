#!/bin/bash
set -e

# Debian 13 (Trixie) with SPICE Clipboard & USB Support
# This script demonstrates QEMU with full SPICE features:
# - Clipboard sharing (copy/paste between host and guest)
# - Better mouse integration (no capture mode)
# - USB redirection support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$HOME/.cache/qemu-demos"
DEBIAN_VERSION="13"
DEBIAN_CODENAME="trixie"

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
    arm64|aarch64)
        QEMU_ARCH="aarch64"
        DEBIAN_ARCH="arm64"
        QEMU_BIN="qemu-system-aarch64"
        MACHINE_ARGS="-machine virt,accel=hvf -cpu host"
        GPU_DEVICE="virtio-gpu-pci"
        # UEFI firmware for ARM
        BIOS_ARGS="-bios /opt/homebrew/Cellar/qemu-spice/10.1.2/share/qemu/edk2-aarch64-code.fd"
        ;;
    x86_64|amd64)
        QEMU_ARCH="x86_64"
        DEBIAN_ARCH="amd64"
        QEMU_BIN="qemu-system-x86_64"
        MACHINE_ARGS="-machine q35,accel=hvf"
        GPU_DEVICE="virtio-vga-gl"
        BIOS_ARGS=""
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Image details
IMAGE_NAME="debian-${DEBIAN_VERSION}-nocloud-${DEBIAN_ARCH}.qcow2"
IMAGE_URL="https://cloud.debian.org/images/cloud/${DEBIAN_CODENAME}/latest/${IMAGE_NAME}"
IMAGE_PATH="$CACHE_DIR/$IMAGE_NAME"

echo "=================================================="
echo "Debian $DEBIAN_VERSION ($DEBIAN_CODENAME) SPICE Demo"
echo "=================================================="
echo ""
echo "Architecture: $DEBIAN_ARCH ($ARCH)"
echo "QEMU Binary: $QEMU_BIN"
echo "Image: $IMAGE_NAME"
echo ""
echo "SPICE Features:"
echo "  - Clipboard sharing (copy/paste)"
echo "  - Smart mouse (no capture mode)"
echo "  - USB redirection ready"
echo "  - Audio/video streaming"
echo ""

# Create cache directory
mkdir -p "$CACHE_DIR"

# Download image if not cached
if [ ! -f "$IMAGE_PATH" ]; then
    echo "Downloading Debian cloud image (~380MB)..."
    echo "URL: $IMAGE_URL"
    curl -L -o "$IMAGE_PATH" "$IMAGE_URL"
    echo "Download complete!"
else
    echo "Using cached image: $IMAGE_PATH"
fi

echo ""
echo "IMPORTANT: After boot, install spice-vdagent in the guest:"
echo "  apt update && apt install -y spice-vdagent"
echo "  systemctl enable --now spice-vdagentd"
echo ""
echo "Display options:"
echo "  1. Using spice-app (QEMU built-in SPICE viewer)"
echo "  2. Fallback to cocoa if spice-app has issues"
echo ""
echo "SPICE server running on: localhost:5900"
echo ""
echo "To stop the VM: Press Ctrl+C in the terminal"
echo ""
echo "Press Enter to start..."
read

# Run QEMU with SPICE
$QEMU_BIN \
    $MACHINE_ARGS \
    $BIOS_ARGS \
    -m 2G \
    -smp 2 \
    -drive file="$IMAGE_PATH",format=qcow2,if=virtio \
    -device $GPU_DEVICE \
    -display spice-app,gl=off \
    -audio spice \
    -device intel-hda \
    -device hda-duplex \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-rng-pci \
    -device virtio-keyboard-pci \
    -device virtio-tablet-pci \
    -serial stdio \
    -spice port=5900,addr=127.0.0.1,disable-ticketing=on,streaming-video=filter \
    -device virtio-serial-pci \
    -chardev qemu-vdagent,id=ch1,name=vdagent,clipboard=on \
    -device virtserialport,chardev=ch1,name=com.redhat.spice.0 \
    -device nec-usb-xhci,id=usb \
    -chardev spicevmc,name=usbredir,id=usbredirchardev1 \
    -device usb-redir,chardev=usbredirchardev1,id=usbredirdev1 \
    -chardev spicevmc,name=usbredir,id=usbredirchardev2 \
    -device usb-redir,chardev=usbredirchardev2,id=usbredirdev2 \
    -chardev spicevmc,name=usbredir,id=usbredirchardev3 \
    -device usb-redir,chardev=usbredirchardev3,id=usbredirdev3
