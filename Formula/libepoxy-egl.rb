class LibepoxyEgl < Formula
  desc "Library for handling OpenGL function pointer management (with EGL support for macOS)"
  homepage "https://github.com/anholt/libepoxy"
  url "https://github.com/anholt/libepoxy/archive/refs/tags/1.5.10.tar.gz"
  sha256 "a7ced37f4102b745ac86d6a70a9da399cc139ff168ba6b8002b4d8d43c900c15"
  license "MIT"
  head "https://github.com/anholt/libepoxy.git", branch: "master"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "freeglut"
  depends_on "mesa"

  conflicts_with "libepoxy", because: "this formula provides libepoxy with EGL support enabled"

  # Enable EGL platform support on macOS/Darwin
  patch :DATA

  def install
    # Optimize for Apple Silicon
    ENV.append "CFLAGS", "-O3 -march=armv8.5-a" if Hardware::CPU.arm?

    system "meson", "setup", "build", "-Degl=yes", *std_meson_args
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
index 1234567..abcdefg 100644
--- a/meson.build
+++ b/meson.build
@@ -44,7 +44,7 @@ endif
 
 enable_egl = get_option('egl')
 if enable_egl == 'auto'
-  build_egl = not ['windows', 'darwin'].contains(host_system)
+  build_egl = not ['windows'].contains(host_system)
 else
   build_egl = enable_egl == 'yes'
 endif
diff --git a/src/dispatch_common.h b/src/dispatch_common.h
index abcdefg..1234567 100644
--- a/src/dispatch_common.h
+++ b/src/dispatch_common.h
@@ -28,7 +28,7 @@
 #define PLATFORM_HAS_GLX ENABLE_GLX
 #define PLATFORM_HAS_WGL 1
 #elif defined(__APPLE__)
-#define PLATFORM_HAS_EGL 0 
+#define PLATFORM_HAS_EGL ENABLE_EGL
 #define PLATFORM_HAS_GLX ENABLE_GLX
 #define PLATFORM_HAS_WGL 0
 #elif defined(ANDROID)
