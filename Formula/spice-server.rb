class SpiceServer < Formula
  desc "SPICE server library for virtual desktop infrastructure"
  homepage "https://www.spice-space.org/"
  url "https://gitlab.freedesktop.org/spice/spice/-/archive/v0.15.2/spice-v0.15.2.tar.bz2"
  sha256 "5b0a4af620565fde831eed69fc485f2aa0a01283d05d254a4c0f388128c6a162"
  license "LGPL-2.1-or-later"
  head "https://gitlab.freedesktop.org/spice/spice.git", branch: "master"

  resource "spice-common" do
    url "https://gitlab.freedesktop.org/spice/spice-common/-/archive/58d375e5eadc6fb9e587e99fd81adcb95d01e8d6/spice-common-58d375e5eadc6fb9e587e99fd81adcb95d01e8d6.tar.gz"
    sha256 "c9a2cfaef9505fa5ce82add6d68461c8daa60b4eb567933c1dd9138db52b5e45"
  end

  resource "pyparsing" do
    url "https://files.pythonhosted.org/packages/source/p/pyparsing/pyparsing-3.2.1.tar.gz"
    sha256 "61980854fd66de3a90028d679a954d5f2a66dbf2e4e26159d4ab806f45fa8bb3"
  end

  resource "six" do
    url "https://files.pythonhosted.org/packages/source/s/six/six-1.17.0.tar.gz"
    sha256 "ff70335d468e7eb6ec65b95b99d3a2836546063f63acc5171de367e8a4b43f29"
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3.13" => :build
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

    # Create isolated Python virtual environment for build dependencies
    venv_dir = buildpath/"venv"
    system Formula["python@3.13"].opt_bin/"python3.13", "-m", "venv", venv_dir
    
    # Install Python dependencies (required by spice-common)
    # - pyparsing: used by spice_codegen.py parser
    # - six: Python 2/3 compatibility library required by meson.build
    system venv_dir/"bin/pip", "install", "--quiet", "pyparsing", "six"
    
    # Use venv Python for the build
    ENV.prepend_path "PATH", venv_dir/"bin"

    # Extract spice-common submodule
    resource("spice-common").stage(buildpath/"subprojects/spice-common") unless build.head?

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
