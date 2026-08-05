class QemuSpice < Formula
  desc "QEMU with SPICE remote-display protocol support"
  homepage "https://www.qemu.org/"
  url "https://download.qemu.org/qemu-11.0.3.tar.xz"
  sha256 "da5fcffc32762820568b828ed430a728864d34d50b6d2f30358597760cbb0523"
  license "GPL-2.0-only"
  head "https://gitlab.com/qemu-project/qemu.git", branch: "master"

  livecheck do
    url "https://www.qemu.org/download/"
    regex(/href=.*?qemu[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  # This formula is homebrew-core's `qemu` with SPICE enabled. Homebrew-core
  # deliberately does not ship SPICE: it was enabled in Homebrew/homebrew-core#226935
  # and reverted a week later in Homebrew/homebrew-core#227722 ("Too many
  # dependencies") because spice-server pulls in gstreamer, opus, orc and openssl@3.
  #
  # Everything below is kept byte-for-byte in sync with core's Formula/q/qemu.rb
  # except the blocks marked "SPICE divergence". Run `make sync-check` to diff
  # this formula against the current core formula.

  depends_on "libtool" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "python-setuptools" => :build
  depends_on "python@3.14" => :build # keep aligned with meson
  depends_on "spice-protocol" => :build

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
  depends_on "pixman"
  depends_on "snappy"
  depends_on "spice-server" # SPICE divergence
  depends_on "usbredir"     # SPICE divergence: USB redirection over SPICE
  depends_on "vde"
  depends_on "zstd"

  uses_from_macos "bison" => :build
  uses_from_macos "flex" => :build
  uses_from_macos "bzip2"

  on_linux do
    depends_on "attr"
    depends_on "cairo"
    depends_on "elfutils"
    depends_on "gdk-pixbuf"
    depends_on "gtk+3"
    depends_on "keyutils"
    depends_on "libcap-ng"
    depends_on "libepoxy"
    depends_on "libx11"
    depends_on "libxkbcommon"
    depends_on "mesa"
    depends_on "systemd"
    depends_on "zlib-ng-compat"
  end

  conflicts_with "qemu", because: "both install qemu-system-* binaries"

  # SPICE divergence: this tap ships no bottles, so every install is a source
  # build. Core builds all ~28 system targets; we build the six that are useful
  # on a macOS host, which cuts the build from hours to minutes.
  TARGETS = %w[
    aarch64-softmmu
    arm-softmmu
    i386-softmmu
    riscv32-softmmu
    riscv64-softmmu
    x86_64-softmmu
  ].freeze

  def install
    ENV["LIBTOOL"] = "glibtool"

    # Remove wheels unless explicitly permitted. Currently this:
    # * removes `meson` so that brew `meson` is always used
    # * keeps `pycotap` and `qemu_qmp` which are pure-python "none-any" wheels (allowed in homebrew/core)
    rm(Dir["python/wheels/*"] - Dir["python/wheels/{pycotap,qemu_qmp}-*-none-any.whl"])

    args = %W[
      --prefix=#{prefix}
      --cc=#{ENV.cc}
      --host-cc=#{ENV.cc}
      --disable-bsd-user
      --disable-download
      --disable-guest-agent
      --enable-slirp
      --enable-capstone
      --enable-curses
      --enable-fdt=system
      --enable-libssh
      --enable-vde
      --enable-virtfs
      --enable-zstd
      --extra-cflags=-DNCURSES_WIDECHAR=1
      --disable-sdl
    ]

    # SPICE divergence: the entire reason this tap exists.
    #
    # Note there is deliberately no --enable-opengl/--enable-virglrenderer here.
    # QEMU's SPICE GL path is gated on HAVE_SPICE_GL, which requires
    # CONFIG_OPENGL && CONFIG_GBM (include/ui/spice-display.h). GBM is a Mesa/DRM
    # component that does not exist on macOS, so `-spice gl=on` is not even a
    # registered option in a macOS build, `-display cocoa,gl=on` errors with
    # "OpenGL is not supported by display backend 'cocoa'", and virtio-gpu-gl
    # cannot bind. Building virglrenderer/libepoxy against this achieved nothing.
    args += %w[
      --enable-spice
      --enable-usb-redir
    ]

    # SPICE divergence: reduced target list, see TARGETS above.
    args << "--target-list=#{TARGETS.join(",")}"

    # Sharing Samba directories in QEMU requires the samba.org smbd which is
    # incompatible with the macOS-provided version. This will lead to
    # silent runtime failures, so we set it to a Homebrew path in order to
    # obtain sensible runtime errors. This will also be compatible with
    # Samba installations from external taps.
    args << "--smbd=#{HOMEBREW_PREFIX}/sbin/samba-dot-org-smbd"

    args += if OS.mac?
      ["--disable-gtk", "--enable-cocoa"]
    else
      ["--enable-gtk"]
    end

    system "./configure", *args
    system "make", "V=1", "install"
  end

  def caveats
    <<~EOS
      This is QEMU #{version} with SPICE enabled. It conflicts with the core
      `qemu` formula because both install qemu-system-* binaries.

      Start a VM with a SPICE server:
        qemu-system-aarch64 -M virt -accel hvf -cpu host -m 4G \\
          -device virtio-gpu-pci \\
          -display none \\
          -spice port=5900,disable-ticketing=on \\
          -device virtio-serial-pci \\
          -chardev spicevmc,id=vdagent,name=vdagent \\
          -device virtserialport,chardev=vdagent,name=com.redhat.spice.0

      Then connect a client. spice-gtk provides the `spicy` viewer:
        brew install spice-gtk
        spicy -h 127.0.0.1 -p 5900

      Note there is no virt-viewer formula or cask in Homebrew, so
      `remote-viewer` is not available on macOS via brew.

      HVF acceleration only works when the guest architecture matches the host,
      so on Apple Silicon use qemu-system-aarch64. x86_64 guests run under TCG
      emulation and are substantially slower.

      There is no GPU acceleration. QEMU's SPICE GL path requires GBM, which is
      Linux-only; see docs/KNOWN-ISSUES.md. For GPU-accelerated VMs on Apple
      Silicon, use UTM or Virtualization.framework instead.
    EOS
  end

  test do
    TARGETS.each do |target|
      guest_arch = target.delete_suffix("-softmmu")
      assert_match version.to_s, shell_output("#{bin}/qemu-system-#{guest_arch} --version")
    end

    system bin/"qemu-img", "create", "-f", "qcow2", "test.qcow2", "1440k"
    assert_match "file format: qcow2", shell_output("#{bin}/qemu-img info test.qcow2")

    system bin/"qemu-img", "convert", "-O", "raw", "test.qcow2", "test.img"
    assert_match "file format: raw", shell_output("#{bin}/qemu-img info test.img")

    # The point of this tap: SPICE must be compiled in. A build without it
    # rejects -spice as an invalid option, so this is the regression guard.
    # `-spice help` prints the option list and exits 1, hence the expected code.
    assert_match "spice options:", shell_output("#{bin}/qemu-system-aarch64 -spice help 2>&1", 1)

    # qxl and usb-redir only exist when SPICE support is present.
    devices = shell_output("#{bin}/qemu-system-x86_64 -device help 2>&1")
    assert_match "qxl", devices
    assert_match "usb-redir", devices

    # On macOS, verify that we haven't clobbered the signature on the qemu-system-x86_64 binary
    if OS.mac?
      output = shell_output("codesign --verify --verbose #{bin}/qemu-system-x86_64 2>&1")
      assert_match "valid on disk", output
      assert_match "satisfies its Designated Requirement", output
    end
  end
end
