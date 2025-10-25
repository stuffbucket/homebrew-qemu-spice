class SpiceServer < Formula
  desc "SPICE server library for virtual desktop infrastructure"
  homepage "https://www.spice-space.org/"
  url "https://gitlab.freedesktop.org/spice/spice/-/archive/v0.15.2/spice-v0.15.2.tar.bz2"
  sha256 "8ff3ca0d6a4e9a8550b2e3b8b997b5db2fadbec871a62c6caa2c7f29d1b7e43b"
  license "LGPL-2.1-or-later"
  head "https://gitlab.freedesktop.org/spice/spice.git", branch: "master"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "spice-protocol" => :build

  depends_on "glib"
  depends_on "gnutls"
  depends_on "jpeg-turbo"
  depends_on "lz4"
  depends_on "openssl@3"
  depends_on "opus"
  depends_on "pixman"
  depends_on "cyrus-sasl"

  on_macos do
    depends_on "gettext"
  end

  def install
    ENV["LIBTOOL"] = "glibtool"

    # Optimize for Apple Silicon
    if Hardware::CPU.arm?
      ENV.append "CFLAGS", "-O3 -march=armv8.5-a -mtune=native"
      ENV.append "CXXFLAGS", "-O3 -march=armv8.5-a -mtune=native"
    end

    # Use meson if available, fallback to configure
    if build.head? || File.exist?("meson.build")
      system "meson", "setup", "build", *std_meson_args,
             "-Dgstreamer=no",
             "-Dlz4=true",
             "-Dsasl=true",
             "-Dopus=enabled",
             "-Dsmartcard=disabled",
             "-Dmanual=false"
      system "meson", "compile", "-C", "build", "--verbose"
      system "meson", "install", "-C", "build"
    else
      system "autoreconf", "-fiv" unless File.exist?("configure")
      system "./configure", "--prefix=#{prefix}",
             "--disable-silent-rules",
             "--disable-celt051",
             "--disable-smartcard",
             "--without-sasl",
             "--enable-lz4",
             "--enable-opus"
      system "make", "install"
    end
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <spice.h>
      int main() {
        SpiceCoreInterface core;
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-I#{include}/spice-server",
           "-I#{Formula["spice-protocol"].include}/spice-1",
           "-I#{Formula["glib"].include}/glib-2.0",
           "-I#{Formula["glib"].lib}/glib-2.0/include",
           "-o", "test"
  end
end
