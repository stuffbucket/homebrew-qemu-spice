#!/bin/bash
# Verification script for QEMU-SPICE installation
# Run this after installation to verify everything works

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "QEMU-SPICE Installation Verification"
echo "=========================================="
echo ""

# Function to check command exists
check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 found"
        return 0
    else
        echo -e "${RED}✗${NC} $1 not found"
        return 1
    fi
}

# Function to check feature
check_feature() {
    if $1 | grep -q "$2"; then
        echo -e "${GREEN}✓${NC} $3"
        return 0
    else
        echo -e "${RED}✗${NC} $3"
        return 1
    fi
}

echo "1. Checking QEMU Installation..."
echo "-----------------------------------"
check_command "qemu-system-x86_64" || exit 1
check_command "qemu-system-aarch64" || exit 1
check_command "qemu-img" || exit 1
check_command "qemu-spice-vm" || exit 1
echo ""

echo "2. Checking QEMU Version..."
echo "-----------------------------------"
VERSION=$(qemu-system-x86_64 --version | head -n1)
echo "   $VERSION"
if [[ "$VERSION" == *"10.1"* ]]; then
    echo -e "${GREEN}✓${NC} Version 10.1.x detected (expected)"
elif [[ "$VERSION" == *"10."* ]]; then
    echo -e "${GREEN}✓${NC} QEMU 10.x detected"
else
    echo -e "${YELLOW}⚠${NC} Expected QEMU 10.1.2, got: $VERSION"
fi
echo ""

echo "3. Checking SPICE Support..."
echo "-----------------------------------"
check_feature "qemu-system-x86_64 -device help" "spice-vmc" "SPICE VMC device" || exit 1
check_feature "qemu-system-x86_64 -device help" "virtio-vga-gl" "VirtIO VGA with GL" || exit 1
check_feature "qemu-system-x86_64 -device help" "virtserialport" "VirtIO serial port" || exit 1
echo ""

echo "4. Checking Accelerator Support..."
echo "-----------------------------------"
check_feature "qemu-system-x86_64 -accel help" "hvf" "HVF (Hypervisor.framework)" || echo -e "${YELLOW}⚠${NC} HVF not available (are you on Apple Silicon?)"
check_feature "qemu-system-x86_64 -accel help" "tcg" "TCG (software emulation)" || exit 1
echo ""

echo "5. Checking Device Support..."
echo "-----------------------------------"
check_feature "qemu-system-x86_64 -device help" "virtio-net-pci" "VirtIO Network" || exit 1
check_feature "qemu-system-x86_64 -device help" "virtio-blk-pci" "VirtIO Block" || exit 1
check_feature "qemu-system-x86_64 -device help" "usb-tablet" "USB Tablet" || exit 1
check_feature "qemu-system-x86_64 -device help" "usb-host" "USB Host (passthrough)" || exit 1
echo ""

echo "6. Checking ARM64 Support..."
echo "-----------------------------------"
check_feature "qemu-system-aarch64 -machine help" "virt" "ARM virt machine" || exit 1
check_feature "qemu-system-aarch64 -device help" "virtio-gpu-gl-pci" "VirtIO GPU with GL" || exit 1
echo ""

echo "7. Checking System Requirements..."
echo "-----------------------------------"
if [[ $(uname -m) == "arm64" ]]; then
    echo -e "${GREEN}✓${NC} Running on Apple Silicon (ARM64)"
    if sysctl kern.hv_support 2>/dev/null | grep -q "kern.hv_support: 1"; then
        echo -e "${GREEN}✓${NC} Hypervisor.framework available"
    else
        echo -e "${RED}✗${NC} Hypervisor.framework not available"
    fi
else
    echo -e "${YELLOW}⚠${NC} Not running on Apple Silicon ($(uname -m))"
fi
echo ""

echo "8. Checking Dependencies..."
echo "-----------------------------------"
check_command "glib-config" || check_command "pkg-config"
if pkg-config --exists glib-2.0; then
    echo -e "${GREEN}✓${NC} GLib found"
fi
if pkg-config --exists spice-server; then
    echo -e "${GREEN}✓${NC} SPICE server library found"
fi
if pkg-config --exists epoxy; then
    echo -e "${GREEN}✓${NC} libepoxy found"
fi
if pkg-config --exists virglrenderer; then
    echo -e "${GREEN}✓${NC} virglrenderer found"
fi
echo ""

echo "9. Creating Test VM (optional)..."
echo "-----------------------------------"
read -p "Would you like to create a test VM? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    TEST_DIR="$HOME/VMs/qemu-test"
    mkdir -p "$TEST_DIR"

    echo "Creating 1GB test disk..."
    if qemu-img create -f qcow2 "$TEST_DIR/test.qcow2" 1G; then
        echo -e "${GREEN}✓${NC} Test disk created at $TEST_DIR/test.qcow2"

        echo ""
        echo "Testing QEMU execution (will timeout after 2 seconds)..."
        if timeout 2 qemu-system-x86_64 \
            -machine q35,accel=hvf \
            -cpu host -smp 2 -m 1G \
            -device virtio-vga-gl \
            -display none \
            -nographic \
            -drive file="$TEST_DIR/test.qcow2",format=qcow2,if=virtio 2>/dev/null || [ $? -eq 124 ]; then
            echo -e "${GREEN}✓${NC} QEMU execution test passed"
        else
            echo -e "${RED}✗${NC} QEMU execution test failed"
        fi

        echo ""
        echo "Test disk can be deleted with:"
        echo "  rm -rf $TEST_DIR"
    fi
fi
echo ""

echo "=========================================="
echo "Verification Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Read QUICKSTART.md to create your first VM"
echo "  2. See EXAMPLES.md for common configurations"
echo "  3. Check README.md for full documentation"
echo ""
echo "Quick test command:"
echo "  mkdir -p ~/VMs"
echo "  cd ~/VMs"
echo "  qemu-img create -f qcow2 test.qcow2 10G"
echo "  qemu-spice-vm -hda test.qcow2 -m 2G -smp 2"
echo ""
