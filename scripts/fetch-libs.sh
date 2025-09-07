#!/bin/bash

# ✅ Create target lib directory
mkdir -p chrome-linux/lib
cd chrome-linux || exit 1

# 📦 List of required packages (matching Chrome dependencies)
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
)

# 📂 Temp directory for extracting .debs
mkdir -p temp
cd temp || exit 1

# 🔄 Update package cache first
echo "🔄 Updating package cache..."
apt-get update > /dev/null 2>&1

# 🔁 Download, extract, and copy .so files
for lib in "${libs[@]}"; do
  echo "📥 Processing $lib..."
  
  # Try to download using apt-get download (more stable)
  if apt-get download "$lib" 2>/dev/null; then
    echo "✅ Downloaded $lib"
  else
    # Fallback: try to download directly from Ubuntu archive
    echo "⚠️ apt-get failed, trying direct download for $lib..."
    
    # Get package info and download URL
    pkg_info=$(apt-cache show "$lib" 2>/dev/null | grep -E "^(Filename|Version):" | head -n2)
    
    if [[ -n "$pkg_info" ]]; then
      filename=$(echo "$pkg_info" | grep "Filename:" | cut -d' ' -f2)
      if [[ -n "$filename" ]]; then
        # Try Ubuntu archive mirrors
        for mirror in "http://archive.ubuntu.com/ubuntu/" "http://security.ubuntu.com/ubuntu/"; do
          url="${mirror}${filename}"
          if wget -q "$url"; then
            echo "✅ Downloaded $lib from $mirror"
            break
          fi
        done
      fi
    fi
    
    # If still no success, try to find any available version
    if ! ls ${lib}_*.deb 2>/dev/null | head -n1 > /dev/null; then
      echo "⚠️ Trying to find any version of $lib..."
      apt-cache search "^${lib}" | head -n1
      pkg_alt=$(apt-cache search "^${lib}" | head -n1 | awk '{print $1}')
      if [[ -n "$pkg_alt" ]]; then
        apt-get download "$pkg_alt" 2>/dev/null || echo "❌ Failed to download $lib"
      fi
    fi
  fi

  # Extract the .deb file if it exists
  deb=$(ls ${lib}_*.deb 2>/dev/null | head -n1)
  if [[ -f "$deb" ]]; then
    echo "📦 Extracting $deb..."
    dpkg-deb -x "$deb" extract/
    
    # Copy all .so files (including symlinks)
    find extract -name "*.so*" -type f -exec cp -v {} ../lib/ \; 2>/dev/null
    find extract -name "*.so*" -type l -exec cp -av {} ../lib/ \; 2>/dev/null
    
    # Clean up extraction
    rm -rf extract/
    rm -f "$deb"
  else
    echo "⚠️ Skipping $lib - .deb not found after all attempts"
  fi
done

# 🧹 Clean up
cd ..
rm -rf temp

# 📋 Create LD_LIBRARY_PATH script
cat > chrome-linux/run-chrome.sh << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="$DIR/lib:$LD_LIBRARY_PATH"
"$DIR/chrome" "$@"
EOF
chmod +x chrome-linux/run-chrome.sh

echo "✅ All libraries have been extracted to chrome-linux/lib"
echo "📝 Created run-chrome.sh wrapper script"