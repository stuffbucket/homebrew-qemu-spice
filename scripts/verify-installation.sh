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
check_feature "qemu-system-x86_64 -device help" "qxl" "SPICE QXL GPU" || exit 1
check_feature "qemu-system-x86_64 -device help" "virtio-vga-gl" "VirtIO VGA with GL (x86_64)" || exit 1
check_feature "qemu-system-aarch64 -device help" "virtio-gpu-gl" "VirtIO GPU with GL (aarch64)" || exit 1
check_feature "qemu-system-x86_64 -device help" "virtserialport" "VirtIO serial port" || exit 1
echo ""

echo "4. Checking SPICE Protocol..."
echo "-----------------------------------"
if qemu-system-aarch64 -spice help 2>&1 | grep -q "port="; then
    echo -e "${GREEN}✓${NC} SPICE protocol available"
    # Check for key SPICE features
    SPICE_HELP=$(qemu-system-aarch64 -spice help 2>&1)
    echo "$SPICE_HELP" | grep -q "gl=" && echo -e "${GREEN}✓${NC} SPICE GL streaming supported"
    echo "$SPICE_HELP" | grep -q "agent-mouse=" && echo -e "${GREEN}✓${NC} SPICE agent support"
else
    echo -e "${RED}✗${NC} SPICE protocol not available"
    exit 1
fi
echo ""

echo "4. Checking SPICE Protocol..."
echo "-----------------------------------"
if qemu-system-aarch64 -spice help 2>&1 | grep -q "port="; then
    echo -e "${GREEN}✓${NC} SPICE protocol available"
    # Check for key SPICE features
    SPICE_HELP=$(qemu-system-aarch64 -spice help 2>&1)
    echo "$SPICE_HELP" | grep -q "gl=" && echo -e "${GREEN}✓${NC} SPICE GL streaming supported"
    echo "$SPICE_HELP" | grep -q "agent-mouse=" && echo -e "${GREEN}✓${NC} SPICE agent support"
else
    echo -e "${RED}✗${NC} SPICE protocol not available"
    exit 1
fi
echo ""

echo "5. Checking Accelerator Support..."
echo "-----------------------------------"
# HVF is only available for native architecture on Apple Silicon
if [[ $(uname -m) == "arm64" ]]; then
    check_feature "qemu-system-aarch64 -accel help" "hvf" "HVF (Hypervisor.framework) - native arm64" || echo -e "${YELLOW}⚠${NC} HVF not available"
    # Verify x86_64 does NOT have HVF (expected)
    if qemu-system-x86_64 -accel help 2>&1 | grep -q "^hvf$"; then
        echo -e "${YELLOW}⚠${NC} Unexpected: HVF in x86_64 binary (should not happen)"
    else
        echo -e "${GREEN}✓${NC} x86_64 correctly uses TCG only (no HVF)"
    fi
else
    echo -e "${YELLOW}⚠${NC} HVF only available on Apple Silicon (current: $(uname -m))"
fi
check_feature "qemu-system-x86_64 -accel help" "tcg" "TCG (software emulation)" || exit 1
echo ""

echo "5. Checking Accelerator Support..."
echo "-----------------------------------"
# HVF is only available for native architecture on Apple Silicon
if [[ $(uname -m) == "arm64" ]]; then
    check_feature "qemu-system-aarch64 -accel help" "hvf" "HVF (Hypervisor.framework) - native arm64" || echo -e "${YELLOW}⚠${NC} HVF not available"
    # Verify x86_64 does NOT have HVF (expected)
    if qemu-system-x86_64 -accel help 2>&1 | grep -q "^hvf$"; then
        echo -e "${YELLOW}⚠${NC} Unexpected: HVF in x86_64 binary (should not happen)"
    else
        echo -e "${GREEN}✓${NC} x86_64 correctly uses TCG only (no HVF)"
    fi
else
    echo -e "${YELLOW}⚠${NC} HVF only available on Apple Silicon (current: $(uname -m))"
fi
check_feature "qemu-system-x86_64 -accel help" "tcg" "TCG (software emulation)" || exit 1
echo ""

echo "6. Checking Device Support..."
echo "-----------------------------------"
check_feature "qemu-system-x86_64 -device help" "virtio-net-pci" "VirtIO Network" || exit 1
check_feature "qemu-system-x86_64 -device help" "virtio-blk-pci" "VirtIO Block" || exit 1
check_feature "qemu-system-x86_64 -device help" "usb-tablet" "USB Tablet" || exit 1
check_feature "qemu-system-x86_64 -device help" "usb-host" "USB Host (passthrough)" || exit 1
check_feature "qemu-system-x86_64 -device help" "intel-hda" "Intel HDA Audio" || exit 1
echo ""

echo "7. Checking Network Backend Support..."
echo "-----------------------------------"
NETDEV_HELP=$(qemu-system-aarch64 -netdev help 2>&1)
echo "$NETDEV_HELP" | grep -q "user" && echo -e "${GREEN}✓${NC} User mode networking (SLIRP)"
echo "$NETDEV_HELP" | grep -q "tap" && echo -e "${GREEN}✓${NC} TAP networking"
echo "$NETDEV_HELP" | grep -q "vmnet" && echo -e "${GREEN}✓${NC} vmnet networking (macOS)" || echo -e "${YELLOW}⚠${NC} vmnet not available (optional)"
echo ""

echo "8. Checking Storage Format Support..."
echo "-----------------------------------"
qemu-img --help | grep -q "qcow2" && echo -e "${GREEN}✓${NC} QCOW2 format supported" || exit 1
qemu-img --help | grep -q "raw" && echo -e "${GREEN}✓${NC} RAW format supported" || exit 1
# Test image creation
TEST_IMG="/tmp/qemu-verify-test-$$.qcow2"
if qemu-img create -f qcow2 "$TEST_IMG" 1M >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Image creation works"
    rm -f "$TEST_IMG"
else
    echo -e "${RED}✗${NC} Image creation failed"
fi
echo ""

echo "8. Checking Storage Format Support..."
echo "-----------------------------------"
qemu-img --help | grep -q "qcow2" && echo -e "${GREEN}✓${NC} QCOW2 format supported" || exit 1
qemu-img --help | grep -q "raw" && echo -e "${GREEN}✓${NC} RAW format supported" || exit 1
# Test image creation
TEST_IMG="/tmp/qemu-verify-test-$$.qcow2"
if qemu-img create -f qcow2 "$TEST_IMG" 1M >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Image creation works"
    rm -f "$TEST_IMG"
else
    echo -e "${RED}✗${NC} Image creation failed"
fi
echo ""

echo "9. Checking ARM64 Support..."
echo "-----------------------------------"
check_feature "qemu-system-aarch64 -machine help" "virt" "ARM virt machine" || exit 1
check_feature "qemu-system-aarch64 -device help" "virtio-gpu-gl-pci" "VirtIO GPU with GL" || exit 1
echo ""

echo "10. Checking System Requirements..."
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

echo "11. Checking Dependencies..."
echo "-----------------------------------"
check_command "pkg-config" || exit 1
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

echo "12. Creating Test VM (optional)..."
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
        echo "Testing QEMU startup (native architecture)..."
        # Use native architecture (aarch64 on Apple Silicon) for HVF support
        if [[ $(uname -m) == "arm64" ]]; then
            QEMU_BIN="qemu-system-aarch64"
            MACHINE_ARGS="-machine virt,accel=hvf -cpu host"
            GPU_DEVICE="virtio-gpu-gl"
        else
            QEMU_BIN="qemu-system-x86_64"
            MACHINE_ARGS="-machine q35,accel=tcg"
            GPU_DEVICE="virtio-vga-gl"
        fi
        
        # Just verify QEMU can start with the config (exits immediately with -S)
        if $QEMU_BIN \
            $MACHINE_ARGS -smp 2 -m 1G \
            -device $GPU_DEVICE \
            -display none \
            -S \
            -drive file="$TEST_DIR/test.qcow2",format=qcow2,if=virtio 2>/dev/null &
        then
            QEMU_PID=$!
            sleep 0.5
            if kill -0 $QEMU_PID 2>/dev/null; then
                kill $QEMU_PID 2>/dev/null
                wait $QEMU_PID 2>/dev/null
                echo -e "${GREEN}✓${NC} QEMU startup test passed"
            else
                echo -e "${RED}✗${NC} QEMU crashed on startup"
            fi
        else
            echo -e "${RED}✗${NC} QEMU failed to start"
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
