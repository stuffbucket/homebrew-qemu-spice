# SPICE options reference

Quick reference for the SPICE options available in this build. Run
`qemu-system-aarch64 -spice help` for the authoritative list — note it exits
with status 1 after printing, which is normal.

## Basic server

```bash
-spice addr=127.0.0.1,port=5900,disable-ticketing=on
```

- `port=<num>` — TCP port for the SPICE server
- `addr=<str>` — bind address; use `127.0.0.1` unless you specifically want it
  reachable from the network
- `disable-ticketing=on` — no authentication (see [Security](#security))
- `unix=on` — listen on a UNIX socket instead of TCP
- `ipv4=on` / `ipv6=on` — restrict address family

## Connecting from macOS

```bash
brew install spice-gtk
spicy -h 127.0.0.1 -p 5900
```

`spice-gtk` ships `spicy`, `spicy-screenshot` and `spicy-stats`.

There is **no** `virt-viewer` formula or cask in Homebrew, so `remote-viewer` is
not available on macOS through brew. Run it from a Linux machine, or use
[UTM](https://mac.getutm.app/), which bundles its own SPICE client.

## Guest agent (clipboard, resolution, mouse)

```bash
-device virtio-serial-pci \
-chardev spicevmc,id=vdagent,name=vdagent \
-device virtserialport,chardev=vdagent,name=com.redhat.spice.0
```

This is only the transport. Clipboard sharing and dynamic resolution also
require `spice-vdagent` running inside the guest (`apt install spice-vdagent` /
`dnf install spice-vdagent`).

Related options:

- `agent-mouse=on|off` — seamless mouse integration via the agent
- `disable-copy-paste=on|off` — block clipboard sharing
- `disable-agent-file-xfer=on|off` — block drag-and-drop file transfer

## USB redirection

```bash
-device qemu-xhci,id=xhci \
-chardev spicevmc,name=usbredir,id=usbredir1 \
-device usb-redir,chardev=usbredir1,bus=xhci.0
```

Repeat the `-chardev`/`-device` pair (with distinct ids) for each concurrent
redirected device. Requires `--enable-usb-redir`, which this formula sets.

## Image and video

`streaming-video=<off|all|filter>`

- `off` — no video stream detection (default)
- `filter` — heuristically detect video regions and stream them (usually best)
- `all` — stream aggressively

`on` is **not** a valid value; it produces
`invalid stream video control: on`.

`image-compression=<auto_glz|auto_lz|quic|glz|lz|off>` — `auto_glz` is the
default and is usually right.

`jpeg-wan-compression=<auto|never|always>` and
`zlib-glz-wan-compression=<auto|never|always>` tune behaviour on links SPICE
considers WAN-like.

`video-codec=<str>` — e.g. `spice:mjpeg`, `gstreamer:h264`. Availability
depends on how `spice-server` was built.

`max-refresh-rate=<num>` — cap server-side refresh rate.

## Audio

```bash
-audiodev coreaudio,id=audio0 \
-device intel-hda -device hda-duplex,audiodev=audio0
```

`playback-compression=on|off` controls compression of the SPICE playback
channel.

## Display devices

For a SPICE-only (headless-on-host) VM, `virtio-gpu-pci` is a good default on
aarch64 guests:

```bash
-device virtio-gpu-pci -display none
```

`qxl-vga` is the classic SPICE device and is x86-oriented:

```bash
-device qxl-vga,vram_size=67108864
```

Do **not** use the `-gl` variants (`virtio-gpu-gl`, `virtio-vga-gl`) — they
cannot bind on macOS. See [KNOWN-ISSUES.md](KNOWN-ISSUES.md).

## Security

`disable-ticketing=on` disables authentication completely. Anyone who can reach
the port gets full console control of the VM.

Password via a secret object:

```bash
-object secret,id=sec0,data=YourSecurePassword \
-spice addr=127.0.0.1,port=5900,password-secret=sec0
```

TLS:

```bash
-spice addr=127.0.0.1,tls-port=5901,password-secret=sec0,\
x509-dir=/path/to/certs,tls-channel=main
```

Relevant options: `tls-port`, `tls-ciphers`, `tls-channel`, `plaintext-channel`,
`x509-dir`, `x509-cacert-file`, `x509-cert-file`, `x509-key-file`,
`x509-key-password`, `x509-dh-key-file`, `sasl=on`.

For remote access, tunnelling over SSH is simpler and safer than exposing the
port:

```bash
ssh -N -L 5900:127.0.0.1:5900 user@vmhost
spicy -h 127.0.0.1 -p 5900
```

## Not available on macOS

`gl` and `rendernode` do not appear in `-spice help` on macOS. QEMU compiles
them only when `HAVE_SPICE_GL` is defined, which requires `CONFIG_GBM` — a
Linux-only Mesa/DRM component. Passing `gl=on` gives:

```
Invalid parameter 'gl'
```

See [KNOWN-ISSUES.md](KNOWN-ISSUES.md) for the full explanation.

## Troubleshooting

**`-spice: invalid option`** — you are running a QEMU without SPICE compiled in,
most likely homebrew-core's `qemu`. See [INSTALL.md](INSTALL.md).

**`invalid stream video control: on`** — use `streaming-video=filter`, not `on`.

**Nothing appears to happen after starting QEMU** — with `-display none`, QEMU
waits for a SPICE client. Connect with `spicy`, or add `-display cocoa` for a
local window alongside the SPICE server.

## See also

- [QEMU SPICE documentation](https://www.spice-space.org/qemu.html)
- [SPICE user manual](https://www.spice-space.org/spice-user-manual.html)
- `qemu-system-aarch64 -spice help`
