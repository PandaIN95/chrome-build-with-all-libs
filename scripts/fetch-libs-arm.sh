#!/bin/bash

# ✅ Create target lib directory
mkdir -p chromium-linux-arm64/lib
cd chromium-linux-arm64 || exit 1

# 📦 List of required packages (matching your previous `ldd` output)
libs=(
  libatk1.0-0
  libatk-bridge2.0-0
  libcups2
  libgbm1
  libgtk-3-0
  libasound2
  libnss3
  libxshmfence1
  libdrm2
  libdbus-1-3
  libglib2.0-0
  libgdk-pixbuf2.0-0
  libpango-1.0-0
  libpangocairo-1.0-0
  libcurl4
  libxcomposite1
  libxdamage1
  libxrandr2
  libx11-6
  libxext6
  libexpat1
  libxi6
  libxrender1
  libcairo2
  libudev1
  libpcre3
  libxcb1
  libxkbcommon0
  libatspi2.0-0
  libavahi-common3
  libavahi-client3
  libnspr4
  libffi8
)

# 📂 Temp directory for extracting .debs
mkdir -p temp
cd temp || exit 1

# 🔁 Download, extract, and copy .so files
for lib in "${libs[@]}"; do
  echo "📥 Downloading $lib for ARM64..."
  apt download "$lib" || echo "❌ Failed to download $lib"

  deb=$(ls ${lib}_*.deb 2>/dev/null | head -n1)
  if [[ -f "$deb" ]]; then
    echo "📦 Extracting $deb..."
    dpkg-deb -x "$deb" extract/
    # Copy from ARM64 library paths
    cp -v extract/usr/lib/aarch64-linux-gnu/*.so* ../lib/ 2>/dev/null
    cp -v extract/lib/aarch64-linux-gnu/*.so* ../lib/ 2>/dev/null
  else
    echo "⚠️ Skipping $lib - .deb not found"
  fi
done

# 🧹 Clean up
cd ..
rm -rf temp

echo "✅ All ARM64 libraries have been extracted to chromium-linux-arm64/lib"