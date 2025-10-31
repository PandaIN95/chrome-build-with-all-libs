#!/bin/bash

ARCH=$1

if [[ -z "$ARCH" ]]; then
  echo "❌ Architecture argument missing! Usage: ./fetch-libs.sh [amd64|arm64]"
  exit 1
fi

# ✅ Create target lib directory
mkdir -p chrome-linux-$ARCH/lib
cd chrome-linux-$ARCH || exit 1

# 📦 List of required packages
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
  echo "📥 Downloading $lib for $ARCH..."
  apt download "${lib}:${ARCH}" >/dev/null 2>&1 || echo "❌ Failed to download $lib for $ARCH"

  deb=$(ls ${lib}_*.deb 2>/dev/null | head -n1)
  if [[ -f "$deb" ]]; then
    echo "📦 Extracting $deb..."
    dpkg-deb -x "$deb" extract/
    cp -v extract/usr/lib/${ARCH}-linux-gnu/*.so* ../lib/ 2>/dev/null
    cp -v extract/lib/${ARCH}-linux-gnu/*.so* ../lib/ 2>/dev/null
  else
    echo "⚠️ Skipping $lib - .deb not found for $ARCH"
  fi
done

# 🧹 Clean up
cd ..
rm -rf temp

echo "✅ All libraries have been extracted for $ARCH to chrome-linux-$ARCH/lib"
