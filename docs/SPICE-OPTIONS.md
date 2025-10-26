# SPICE Options Reference

Quick reference for common SPICE options in QEMU.

## Basic SPICE Server Configuration

```bash
-spice port=5900,addr=127.0.0.1,disable-ticketing=on
```

- `port=5900` - SPICE server port (default: 5900)
- `addr=127.0.0.1` - Bind to localhost only (secure)
- `disable-ticketing=on` - No authentication (use for local testing only)

## Streaming Video Options

**Option:** `streaming-video=<value>`

**Valid values:**

- `off` - Disable video streaming optimization (default)
- `all` - Stream all video content aggressively
- `filter` - Automatically detect and stream video content (recommended)

**Invalid:** ~~`on`~~ (not a valid value)

**Example:**
```bash
-spice port=5900,disable-ticketing=on,streaming-video=filter
```

## Agent Mouse

**Option:** `agent-mouse=<on|off>`

Enables seamless mouse integration when SPICE agent is running in the guest.

```bash
-spice agent-mouse=on
```

## Image Compression

**Option:** `image-compression=<value>`

**Valid values:**

- `auto_glz` - Automatic with GLZ compression (default)
- `auto_lz` - Automatic with LZ compression
- `quic` - QUIC image compression
- `glz` - GLZ compression
- `lz` - LZ compression
- `off` - No compression

## Playback Compression

**Option:** `playback-compression=<on|off>`

Enable/disable audio compression.

## Common SPICE Device Setup

### With SPICE Agent (Recommended)

```bash
-spice port=5900,addr=127.0.0.1,disable-ticketing=on,streaming-video=filter,agent-mouse=on \
-device virtio-serial-pci \
-chardev spicevmc,id=vdagent,name=vdagent \
-device virtserialport,chardev=vdagent,name=com.redhat.spice.0
```

### Without SPICE Agent (Basic)

```bash
-spice port=5900,addr=127.0.0.1,disable-ticketing=on,streaming-video=filter
```

## Display Devices for SPICE

**For remote access (SPICE clients):**

```bash
-device qxl-vga,vram_size=67108864
```

**For local display (Cocoa on macOS):**

```bash
-device virtio-gpu-pci
-display cocoa
```

## Security Notes

⚠️ **For production use:**

- Do NOT use `disable-ticketing=on`
- Use `password-secret=` with proper authentication
- Bind to specific IPs, not `0.0.0.0`
- Consider TLS encryption with `tls-port=`

**Example secure configuration:**

```bash
-spice port=5900,addr=127.0.0.1,password-secret=spice_password,streaming-video=filter \
-object secret,id=spice_password,data=YourSecurePassword
```

## Platform-Specific Notes

### macOS (Cocoa Display)

- ❌ `gl=on` - Not supported (Linux X11/Wayland only)
- ✅ SPICE server works (for remote access)
- ✅ VirGL GPU acceleration via virtio-gpu-pci
- ⚠️ No native SPICE client for macOS (use remote-viewer via XQuartz or Linux VM)

### Linux

- ✅ Full SPICE client support via `remote-viewer`
- ✅ `gl=on` support with X11/Wayland
- ✅ All SPICE features available

## Troubleshooting

### Error: "invalid stream video control: on"

**Problem:** Using `streaming-video=on` (invalid value)

**Solution:** Use `streaming-video=filter` (or `off`/`all`)

### Error: "No SPICE client connected"

This is not an error - QEMU is waiting for a SPICE client to connect. Use:

```bash
remote-viewer spice://127.0.0.1:5900
```

Or just use the local Cocoa display without connecting a SPICE client.

## See Also

- [QEMU SPICE Documentation](https://www.spice-space.org/qemu.html)
- [SPICE User Manual](https://www.spice-space.org/spice-user-manual.html)
- Run `qemu-system-aarch64 -spice help` for all options
