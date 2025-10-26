class QemuSpice < Formula
  desc "QEMU with SPICE support and Apple Silicon optimizations"
  homepage "https://www.qemu.org/"
  url "https://download.qemu.org/qemu-10.1.2.tar.xz"
  sha256 "9d75f331c1a5cb9b6eb8fd9f64f563ec2eab346c822cb97f8b35cd82d3f11479"
  license "GPL-2.0-only"
  head "https://gitlab.com/qemu-project/qemu.git", branch: "master"

  depends_on "libtool" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3.12" => :build

  # SPICE dependencies
  depends_on "spice-protocol" => :build
  depends_on "libepoxy-egl"
  depends_on "spice-server"
  depends_on "virglrenderer"

  # Core QEMU dependencies
  depends_on "capstone"
  depends_on "dtc"
  depends_on "glib"
  depends_on "gnutls"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "libslirp"
  depends_on "libssh"
  depends_on "libusb"
  depends_on "lzo"
  depends_on "ncurses"
  depends_on "nettle"
  depends_on "pixman"
  depends_on "snappy"
  depends_on "usbredir"
  depends_on "vde"
  depends_on "zstd"

  uses_from_macos "bison" => :build
  uses_from_macos "flex" => :build
  uses_from_macos "bzip2"
  uses_from_macos "zlib"

  on_linux do
    depends_on "attr"
    depends_on "cairo"
    depends_on "elfutils"
    depends_on "gdk-pixbuf"
    depends_on "gtk+3"
    depends_on "libcap-ng"
    depends_on "libx11"
    depends_on "libxkbcommon"
    depends_on "mesa"
    depends_on "systemd"
  end

  fails_with gcc: "5"

  def install
    ENV["LIBTOOL"] = "glibtool"

    # Apple Silicon optimizations
    if Hardware::CPU.arm?
      ENV.append "CFLAGS", "-O3 -march=armv8.5-a -mtune=native"
      ENV.append "CXXFLAGS", "-O3 -march=armv8.5-a -mtune=native"
      ENV.append "LDFLAGS", "-Wl,-no_warn_duplicate_libraries"
    end

    # Target list optimized for ARM64 host
    # Focus on aarch64, x86_64, and common architectures
    target_list = %w[
      aarch64-softmmu
      arm-softmmu
      x86_64-softmmu
      i386-softmmu
      riscv64-softmmu
      riscv32-softmmu
    ]

    args = %W[
      --prefix=#{prefix}
      --sysconfdir=#{etc}
      --localstatedir=#{var}
      --disable-bsd-user
      --disable-guest-agent
      --disable-download
      --disable-debug-info
      --disable-werror
      --enable-slirp
      --enable-capstone
      --enable-curses
      --enable-fdt=system
      --enable-libssh
      --enable-vde
      --enable-virtfs
      --enable-zstd
      --extra-cflags=-DNCURSES_WIDECHAR=1
      --enable-cocoa
      --enable-hvf
      --target-list=#{target_list.join(",")}
    ]

    # SPICE and OpenGL support
    args += %w[
      --enable-spice
      --enable-opengl
      --enable-virglrenderer
    ]

    # USB and passthrough support
    args += %w[
      --enable-usb-redir
      --enable-libusb
    ]

    # Audio support
    args += %w[
      --audio-drv-list=coreaudio
      --enable-coreaudio
    ]

    # Disable features not needed on macOS
    args += %w[
      --disable-sdl
      --disable-gtk
    ]

    system "./configure", *args
    system "make", "V=1"
    system "make", "install"

    # Install additional utilities
    bin.install_symlink bin/"qemu-system-aarch64" => "qemu-aarch64"
    bin.install_symlink bin/"qemu-system-x86_64" => "qemu-x86_64"

    # Create wrapper scripts for common VM configurations
    (bin/"qemu-spice-vm").write <<~EOS
      #!/bin/bash
      # QEMU SPICE VM launcher with optimized settings for Apple Silicon
      exec #{bin}/qemu-system-x86_64 \\
        -machine type=q35,accel=hvf \\
        -cpu host \\
        -smp cpus=4,cores=4,threads=1 \\
        -m 4G \\
        -device virtio-vga-gl \\
        -display cocoa,gl=on \\
        -spice port=5900,disable-ticketing=on,gl=on \\
        -device virtio-serial \\
        -chardev spicevmc,id=vdagent,debug=0,name=vdagent \\
        -device virtserialport,chardev=vdagent,name=com.redhat.spice.0 \\
        -audiodev coreaudio,id=audio0 \\
        -device intel-hda \\
        -device hda-duplex,audiodev=audio0 \\
        -device usb-tablet \\
        -device ich9-usb-ehci1,id=usb \\
        -device ich9-usb-uhci1,masterbus=usb.0,firstport=0,multifunction=on \\
        -device ich9-usb-uhci2,masterbus=usb.0,firstport=2 \\
        -device ich9-usb-uhci3,masterbus=usb.0,firstport=4 \\
        -netdev user,id=net0 \\
        -device virtio-net-pci,netdev=net0 \\
        "$@"
    EOS
    chmod 0755, bin/"qemu-spice-vm"
  end

  def post_install
    (var/"qemu").mkpath
  end

  test do
    # Test that QEMU binaries run
    expected = "QEMU emulator version"

    # Test aarch64 emulator
    assert_match expected, shell_output("#{bin}/qemu-system-aarch64 --version")

    # Test x86_64 emulator
    assert_match expected, shell_output("#{bin}/qemu-system-x86_64 --version")

    # Verify SPICE support is compiled in (check for QXL device)
    assert_match "qxl", shell_output("#{bin}/qemu-system-x86_64 -device help")

    # Verify virtio-vga-gl support (x86_64)
    assert_match "virtio-vga-gl", shell_output("#{bin}/qemu-system-x86_64 -device help")

    # Verify virtio-gpu-gl support (aarch64)
    assert_match "virtio-gpu-gl", shell_output("#{bin}/qemu-system-aarch64 -device help")

    # Verify HVF (Hypervisor.framework) support on Apple Silicon
    # HVF is only available for native architecture emulation
    if OS.mac? && Hardware::CPU.arm?
      assert_match "hvf", shell_output("#{bin}/qemu-system-aarch64 -accel help")
    end

    # Test that QEMU can actually start with a real configuration
    # Use native architecture for faster testing
    if Hardware::CPU.arm?
      # Test ARM64 on Apple Silicon (native, with HVF)
      # Create a tiny test disk
      system "#{bin}/qemu-img", "create", "-f", "qcow2", "#{testpath}/test.qcow2", "1M"
      
      # Start QEMU with -S (paused) and verify it runs
      (testpath/"qemu-test.sh").write <<~EOS
        #!/bin/bash
        #{bin}/qemu-system-aarch64 \\
          -M virt,accel=hvf \\
          -cpu host \\
          -m 128M \\
          -drive file=#{testpath}/test.qcow2,if=virtio \\
          -nographic \\
          -S &
        PID=$!
        sleep 1
        if kill -0 $PID 2>/dev/null; then
          kill $PID
          wait $PID 2>/dev/null
          exit 0
        else
          exit 1
        fi
      EOS
    else
      # Test x86_64 on Intel Macs (native)
      system "#{bin}/qemu-img", "create", "-f", "qcow2", "#{testpath}/test.qcow2", "1M"
      
      (testpath/"qemu-test.sh").write <<~EOS
        #!/bin/bash
        #{bin}/qemu-system-x86_64 \\
          -M q35 \\
          -cpu qemu64 \\
          -m 128M \\
          -drive file=#{testpath}/test.qcow2,if=virtio \\
          -nographic \\
          -S &
        PID=$!
        sleep 1
        if kill -0 $PID 2>/dev/null; then
          kill $PID
          wait $PID 2>/dev/null
          exit 0
        else
          exit 1
        fi
      EOS
    end
    chmod 0755, testpath/"qemu-test.sh"
    system testpath/"qemu-test.sh"
  end

  def caveats
    <<~EOS
      QEMU with SPICE support has been installed with Apple Silicon optimizations.

      Key features enabled:
      - SPICE protocol for remote display
      - OpenGL/virglrenderer for GPU acceleration
      - Hypervisor.framework (HVF) for native virtualization
      - USB device passthrough support
      - VirtIO devices for optimal performance
      - CoreAudio passthrough for guest audio

      To start a VM with SPICE support:
        #{bin}/qemu-spice-vm -cdrom /path/to/iso -hda /path/to/disk.img

      Or manually with full control:
        #{bin}/qemu-system-x86_64 \\
          -machine type=q35,accel=hvf \\
          -cpu host -smp 4 -m 4G \\
          -device virtio-vga-gl \\
          -display cocoa,gl=on \\
          -spice port=5900,disable-ticketing=on,gl=on

      For USB passthrough, identify devices with:
        system_profiler SPUSBDataType

      Then add to QEMU command:
        -device usb-host,vendorid=0x1234,productid=0x5678

      Connect to SPICE display with:
        brew install virt-viewer
        remote-viewer spice://localhost:5900

      Documentation: https://www.qemu.org/docs/master/
      SPICE docs: https://www.spice-space.org/documentation.html
    EOS
  end
end
