#!/usr/bin/env bash
#
# verify-installation.sh — check that the installed qemu-spice actually works.
#
# The load-bearing check is SPICE support: a QEMU without it rejects -spice as
# an invalid option, which is exactly what homebrew-core's qemu does. Everything
# else here is secondary.

set -uo pipefail

if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; NC=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; NC=""
fi

pass=0; fail=0; warn=0

ok()    { printf '  %s✓%s %s\n' "$GREEN" "$NC" "$1"; pass=$((pass + 1)); }
bad()   { printf '  %s✗%s %s\n' "$RED" "$NC" "$1";   fail=$((fail + 1)); }
note()  { printf '  %s⚠%s %s\n' "$YELLOW" "$NC" "$1"; warn=$((warn + 1)); }
section() { printf '\n%s=== %s ===%s\n' "$BLUE" "$1" "$NC"; }

# matches <pattern> <command...> — run command, grep its output for pattern.
# QEMU's help subcommands exit non-zero (`-spice help` and `-chardev help` both
# exit 1), so we capture the output first rather than piping directly: under
# `set -o pipefail` a non-zero producer would fail the pipeline even when grep
# matched, which silently turns working features into reported failures.
matches() {
  local pattern="$1"; shift
  local out
  out="$("$@" 2>&1)" || true
  printf '%s\n' "$out" | grep -qE "$pattern"
}

section "Binaries"
for b in qemu-system-aarch64 qemu-system-x86_64 qemu-img; do
  if command -v "$b" >/dev/null 2>&1; then
    ok "$b — $(command -v "$b")"
  else
    bad "$b not found on PATH"
  fi
done

if ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
  printf '\n%sCannot continue: qemu-system-aarch64 not on PATH.%s\n' "$RED" "$NC"
  printf 'Install with: brew install --build-from-source stuffbucket/qemu-spice/qemu-spice\n'
  exit 1
fi

section "Which build is linked"
target="$(command -v qemu-system-aarch64)"
resolved="$(python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$target" 2>/dev/null || echo "$target")"
printf '  %s\n' "$resolved"
case "$resolved" in
  *qemu-spice*) ok "linked build comes from the qemu-spice tap" ;;
  *)            note "this is not the qemu-spice build; SPICE checks will likely fail" ;;
esac
printf '  version: %s\n' "$(qemu-system-aarch64 --version 2>/dev/null | head -1)"

section "SPICE support (the reason this tap exists)"
if matches 'spice options:' qemu-system-aarch64 -spice help; then
  ok "-spice accepted, server options available"
else
  bad "-spice rejected — this QEMU has no SPICE support"
  printf '      A core-qemu build responds: "qemu-system-aarch64: -spice: invalid option"\n'
  printf '      Fix: brew unlink qemu && brew link qemu-spice\n'
fi

for dev in qxl qxl-vga usb-redir; do
  if matches "name \"$dev\"" qemu-system-x86_64 -device help; then
    ok "device $dev"
  else
    bad "device $dev missing"
  fi
done

if matches 'name "virtio-gpu-pci"' qemu-system-aarch64 -device help; then
  ok "device virtio-gpu-pci (aarch64 guest display)"
else
  bad "device virtio-gpu-pci missing"
fi

# `-chardev help` needs a machine to be selected, hence -M none.
if matches 'spicevmc' qemu-system-aarch64 -M none -chardev help; then
  ok "chardev spicevmc (vdagent / usbredir transport)"
else
  bad "chardev spicevmc missing"
fi

section "Acceleration"
accel="tcg"
if matches 'hvf' qemu-system-aarch64 -accel help; then
  ok "HVF available for aarch64 guests"
  accel="hvf"
else
  note "HVF not available — guests will run under TCG emulation"
fi

if [ "$(uname -m)" = "arm64" ]; then
  # HVF only virtualises the host architecture. x86_64 + hvf is expected to fail
  # on Apple Silicon; that is not a defect in this build.
  if matches '^hvf$' qemu-system-x86_64 -accel help; then
    note "x86_64 reports hvf — unexpected on Apple Silicon"
  else
    ok "x86_64 correctly has no HVF on Apple Silicon (TCG only)"
  fi
fi

section "GPU acceleration (expected to be absent)"
# These must NOT be present. QEMU needs CONFIG_GBM for any GL path and macOS has
# no GBM, so a build advertising them would be misleading. See docs/KNOWN-ISSUES.md.
if matches 'virtio-gpu-gl' qemu-system-aarch64 -device help; then
  note "virtio-gpu-gl present but cannot bind on macOS — see docs/KNOWN-ISSUES.md"
else
  ok "no GL device variants (correct for macOS)"
fi

if matches 'gl=' qemu-system-aarch64 -spice help; then
  note "-spice advertises gl= but it cannot work without GBM"
else
  ok "-spice has no gl= option (correct for macOS)"
fi

section "Live SPICE server test"
port=5987
tmpdir="$(mktemp -d)"
disk="$tmpdir/verify.qcow2"

if qemu-img create -f qcow2 "$disk" 32M >/dev/null 2>&1; then
  cpu_args=""
  [ "$accel" = "hvf" ] && cpu_args="-cpu host"

  # shellcheck disable=SC2086
  qemu-system-aarch64 -M virt -accel "$accel" $cpu_args \
    -m 256M -device virtio-gpu-pci -display none \
    -spice "addr=127.0.0.1,port=$port,disable-ticketing=on" \
    -device virtio-serial-pci \
    -chardev spicevmc,id=vdagent,name=vdagent \
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0 \
    -drive file="$disk",if=virtio -S >"$tmpdir/vm.log" 2>&1 &
  vmpid=$!
  sleep 3

  if kill -0 "$vmpid" 2>/dev/null; then
    ok "VM started with SPICE (accel=$accel)"
    if python3 - "$port" <<'PY'
import socket, struct, sys
port = int(sys.argv[1])
try:
    s = socket.create_connection(("127.0.0.1", port), 3)
    # SpiceLinkHeader: magic "REDQ", major, minor, size
    s.sendall(struct.pack("<4sIIII", b"REDQ", 2, 2, 16, 0) + b"\0" * 12)
    good = s.recv(16)[:4] == b"REDQ"
    s.close()
    sys.exit(0 if good else 1)
except Exception:
    sys.exit(1)
PY
    then
      ok "SPICE server completed a protocol handshake on port $port"
    else
      bad "SPICE port did not respond with a valid handshake"
    fi
  else
    bad "VM failed to start"
    sed 's/^/      /' "$tmpdir/vm.log" | head -5
  fi

  kill "$vmpid" 2>/dev/null
  wait "$vmpid" 2>/dev/null
else
  bad "qemu-img could not create a test disk"
fi
rm -rf "$tmpdir"

section "Summary"
printf '  %spassed: %d%s   %sfailed: %d%s   %swarnings: %d%s\n' \
  "$GREEN" "$pass" "$NC" "$RED" "$fail" "$NC" "$YELLOW" "$warn" "$NC"

if [ "$fail" -gt 0 ]; then
  printf '\n%sVerification failed.%s See docs/INSTALL.md for troubleshooting.\n' "$RED" "$NC"
  exit 1
fi
printf '\n%sqemu-spice is installed and serving SPICE correctly.%s\n' "$GREEN" "$NC"
exit 0
