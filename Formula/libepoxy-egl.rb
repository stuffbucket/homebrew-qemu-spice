class LibepoxyEgl < Formula
  desc "Library for handling OpenGL function pointer management (with EGL support for macOS)"
  homepage "https://github.com/anholt/libepoxy"
  url "https://github.com/anholt/libepoxy/archive/refs/tags/1.5.10.tar.gz"
  sha256 "072cda4b59dd098bba8c2363a6247299db1fa89411dc221c8b81b8ee8192e623"
  license "MIT"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "freeglut"

  conflicts_with "libepoxy", because: "this formula provides libepoxy with EGL support enabled"

  # Patch to enable EGL on macOS (required for SPICE OpenGL support)
  patch do
    url "https://github.com/anholt/libepoxy/pull/239.patch"
    sha256 "e88d7fc5c384f93a5c4659c5fc1ac9e5e3d5bb964d5d54bdb97e4e46c1c9b1d4"
  end

  # Enable EGL platform support on macOS/Darwin
  patch :DATA

  def install
    # Optimize for Apple Silicon
    ENV.append "CFLAGS", "-O3 -march=armv8.5-a" if Hardware::CPU.arm?

    system "meson", "setup", "build", *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <epoxy/gl.h>
      #ifdef __APPLE__
        #include <OpenGL/CGLContext.h>
        #include <OpenGL/CGLTypes.h>
      #endif
      int main() {
        #ifdef __APPLE__
          CGLPixelFormatAttribute attribs[] = {0};
          CGLPixelFormatObj pix;
          int npix;
          CGLContextObj ctx;
          CGLChoosePixelFormat(attribs, &pix, &npix);
          CGLCreateContext(pix, (void*)0, &ctx);
        #endif
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-o", "test", "-L#{lib}", "-lepoxy", "-framework", "OpenGL"
    system "./test"
  end
end

__END__
diff --git a/meson.build b/meson.build
index 85e9d93..b3c9bb6 100644
--- a/meson.build
+++ b/meson.build
@@ -195,7 +195,7 @@ if build_glx
 endif

 # On windows, the DLL has to have all of its functions resolved at link time.
-if host_system != 'windows' and host_system != 'darwin'
+if host_system != 'windows'
   egl_dep = dependency('egl', required: false)
   build_egl = egl_dep.found()
   if build_egl
