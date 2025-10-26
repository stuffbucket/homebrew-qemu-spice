# Debian Multimedia Demo: Playing Big Buck Bunny

Once Debian boots (logs in automatically as root):

## 1. Update package lists

```bash
apt update
```

## 2. Install video player and audio tools

```bash
# Install mpv (modern, recommended) + audio utilities
apt install -y mpv alsa-utils

# OR install vlc
# apt install -y vlc alsa-utils

# OR use ffmpeg's ffplay
# apt install -y ffmpeg alsa-utils
```

**Test audio first (optional):**

```bash
# Check if audio device is detected
aplay -l

# Play test sound (white noise)
aplay /usr/share/sounds/alsa/Noise.wav

# Adjust volume if needed
alsamixer
```

## 3. Download Big Buck Bunny

```bash
cd /tmp

# Small version (~10MB) - good for testing
wget http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4

# OR larger HD version (158MB)
# wget https://download.blender.org/demo/movies/BBB/bbb_sunflower_1080p_30fps_normal.mp4 -O BigBuckBunny.mp4
```

## 4. Play it

```bash
# With mpv (works in framebuffer/console):
mpv --vo=drm BigBuckBunny.mp4

# OR with ffplay:
# ffplay BigBuckBunny.mp4

# OR if you have X11/Wayland running:
# mpv BigBuckBunny.mp4
```

## Alternative: Test video without download

```bash
# Install ffmpeg first if not already installed
apt install -y ffmpeg

# Generate test pattern with audio
ffplay -f lavfi -i testsrc=duration=10:size=1280x720:rate=30 -f lavfi -i sine=frequency=1000:duration=10
```

## Notes

- **Debian nocloud images** boot directly to root prompt (no password needed)
- Video will play via **framebuffer** (`--vo=drm` for mpv) since there's no X11/Wayland in the nocloud image
- All packages are from **Debian's main repository** (no need to enable additional repos)
- Internet access works out of the box via user-mode networking
