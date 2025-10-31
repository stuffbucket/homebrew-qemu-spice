class Virglrenderer < Formula
  desc "Virtual GPU renderer for QEMU (macOS port with Apple Silicon optimizations)"
  homepage "https://gitlab.freedesktop.org/virgl/virglrenderer"
  # Using akihikodaki's macOS-compatible fork
  url "https://github.com/akihikodaki/virglrenderer.git",
      branch:   "macos",
      revision: "0a26988c5c4f3009c5b68e83dc0e36fb50e8c4f5"
  version "1.0.1"
  license "MIT"
  head "https://github.com/akihikodaki/virglrenderer.git", branch: "macos"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "libepoxy-egl"

  def install
    # Optimize for Apple Silicon ARM64
    args = std_meson_args

    if Hardware::CPU.arm?
      ENV.append "CFLAGS", "-O3 -march=armv8.5-a -mtune=native"
      ENV.append "CXXFLAGS", "-O3 -march=armv8.5-a -mtune=native"
    end

    system "meson", "setup", "build", *args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  test do
    assert_match "virgl_test_server", shell_output("#{bin}/virgl_test_server --help", 1)
  end
end
