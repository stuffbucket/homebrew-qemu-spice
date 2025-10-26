#!/bin/bash
set -e

# Debian 13 (Trixie) Multimedia Demo with QEMU + SPICE
# This script demonstrates QEMU with SPICE support using a Debian cloud image

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
echo "Debian $DEBIAN_VERSION ($DEBIAN_CODENAME) Demo - QEMU + SPICE"
echo "=================================================="
echo ""
echo "Architecture: $DEBIAN_ARCH ($ARCH)"
echo "QEMU Binary: $QEMU_BIN"
echo "Image: $IMAGE_NAME"
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
echo "Starting Debian VM..."
echo "The VM will boot to a root prompt (no password required)."
echo ""
echo "To stop the VM: Press Ctrl+C in the terminal"
echo ""
echo "Demo instructions: See scripts/DEMO-DEBIAN.md"
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
    -display cocoa,show-cursor=on \
    -audio coreaudio \
    -device intel-hda \
    -device hda-duplex \
    -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8445-:8445 \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-rng-pci \
    -device virtio-keyboard-pci \
    -device virtio-mouse-pci \
    -serial stdio \
    -spice port=5900,addr=127.0.0.1,disable-ticketing=on,streaming-video=filter,agent-mouse=on \
    -device virtio-serial-pci \
    -chardev spicevmc,id=vdagent,name=vdagent \
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0
