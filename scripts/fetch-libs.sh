#!/bin/bash

# This is a simpler alternative that copies libraries directly from the system
# Use this if the main fetch-libs.sh has issues with downloading packages

echo "📦 Simple library extraction - copying from installed system packages"

# ✅ Create target lib directory
mkdir -p chrome-linux/lib
cd chrome-linux || exit 1

# 📦 List of required packages
packages=(
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
  libgdk-pixbuf-2.0-0
  libgdk-pixbuf2.0-0  # Alternative name
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

# First, ensure packages are installed
echo "📥 Installing required packages..."
apt-get update
apt-get install -y "${packages[@]}" 2>/dev/null || true

echo ""
echo "📋 Copying libraries from installed packages..."

# Function to copy libraries from a package
copy_package_libs() {
  local pkg=$1
  
  # Check if package is installed
  if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
    echo "  Processing $pkg..."
    
    # Method 1: Get libraries from dpkg file list
    dpkg -L "$pkg" 2>/dev/null | while read -r file; do
      if [[ "$file" =~ \.so($|\.) ]]; then
        if [[ -f "$file" ]]; then
          # Copy the actual file (following symlinks)
          cp -L "$file" lib/ 2>/dev/null && echo "    ✅ $(basename "$file")"
        fi
      fi
    done
    
    # Method 2: Find libraries in common locations
    for libdir in /usr/lib/x86_64-linux-gnu /usr/lib /lib/x86_64-linux-gnu /lib; do
      if [[ -d "$libdir" ]]; then
        # Try to find libraries that might belong to this package
        find "$libdir" -maxdepth 2 -name "*${pkg#lib}*.so*" -type f 2>/dev/null | while read -r lib; do
          cp -L "$lib" lib/ 2>/dev/null
        done
      fi
    done
  else
    echo "  ⚠️ Package $pkg not installed"
  fi
}

# Copy libraries from each package
for package in "${packages[@]}"; do
  copy_package_libs "$package"
done

echo ""
echo "📋 Copying additional essential libraries..."

# Copy essential runtime libraries that Chrome might need
essential_libs=(
  # C/C++ runtime
  /usr/lib/x86_64-linux-gnu/libstdc++.so*
  /usr/lib/x86_64-linux-gnu/libgcc_s.so*
  /lib/x86_64-linux-gnu/libm.so*
  /lib/x86_64-linux-gnu/libdl.so*
  /lib/x86_64-linux-gnu/libpthread.so*
  /lib/x86_64-linux-gnu/librt.so*
  /lib/x86_64-linux-gnu/libc.so*
  /lib/x86_64-linux-gnu/libresolv.so*
  
  # Graphics related
  /usr/lib/x86_64-linux-gnu/libGL.so*
  /usr/lib/x86_64-linux-gnu/libEGL.so*
  /usr/lib/x86_64-linux-gnu/libGLESv2.so*
  /usr/lib/x86_64-linux-gnu/libGLX.so*
  
  # X11 and display related
  /usr/lib/x86_64-linux-gnu/libX11.so*
  /usr/lib/x86_64-linux-gnu/libXext.so*
  /usr/lib/x86_64-linux-gnu/libXfixes.so*
  /usr/lib/x86_64-linux-gnu/libXi.so*
  /usr/lib/x86_64-linux-gnu/libXrandr.so*
  /usr/lib/x86_64-linux-gnu/libXrender.so*
  /usr/lib/x86_64-linux-gnu/libXcomposite.so*
  /usr/lib/x86_64-linux-gnu/libXdamage.so*
  /usr/lib/x86_64-linux-gnu/libXcursor.so*
  /usr/lib/x86_64-linux-gnu/libXinerama.so*
  /usr/lib/x86_64-linux-gnu/libXtst.so*
  
  # GTK and dependencies
  /usr/lib/x86_64-linux-gnu/libgtk-3.so*
  /usr/lib/x86_64-linux-gnu/libgdk-3.so*
  /usr/lib/x86_64-linux-gnu/libcairo.so*
  /usr/lib/x86_64-linux-gnu/libpango-1.0.so*
  /usr/lib/x86_64-linux-gnu/libgobject-2.0.so*
  /usr/lib/x86_64-linux-gnu/libglib-2.0.so*
  /usr/lib/x86_64-linux-gnu/libgio-2.0.so*
  /usr/lib/x86_64-linux-gnu/libgmodule-2.0.so*
  /usr/lib/x86_64-linux-gnu/libgthread-2.0.so*
  
  # NSS/NSPR
  /usr/lib/x86_64-linux-gnu/libnss3.so*
  /usr/lib/x86_64-linux-gnu/libnssutil3.so*
  /usr/lib/x86_64-linux-gnu/libnspr4.so*
  /usr/lib/x86_64-linux-gnu/libplc4.so*
  /usr/lib/x86_64-linux-gnu/libplds4.so*
  
  # Other important libraries
  /usr/lib/x86_64-linux-gnu/libcups.so*
  /usr/lib/x86_64-linux-gnu/libasound.so*
  /usr/lib/x86_64-linux-gnu/libdbus-1.so*
  /usr/lib/x86_64-linux-gnu/libexpat.so*
  /usr/lib/x86_64-linux-gnu/libfontconfig.so*
  /usr/lib/x86_64-linux-gnu/libfreetype.so*
  /usr/lib/x86_64-linux-gnu/libz.so*
  /usr/lib/x86_64-linux-gnu/libpng*.so*
  /usr/lib/x86_64-linux-gnu/libjpeg.so*
  /usr/lib/x86_64-linux-gnu/libxcb.so*
  /usr/lib/x86_64-linux-gnu/libxkbcommon.so*
  /usr/lib/x86_64-linux-gnu/libwayland-client.so*
  /usr/lib/x86_64-linux-gnu/libwayland-server.so*
)

for lib in "${essential_libs[@]}"; do
  if [[ -f "$lib" ]]; then
    cp -L "$lib" lib/ 2>/dev/null
  fi
done

# Also handle glob patterns
for pattern in "${essential_libs[@]}"; do
  for file in $pattern; do
    if [[ -f "$file" ]]; then
      cp -L "$file" lib/ 2>/dev/null
    fi
  done
done

# Remove any broken symlinks
find lib -type l ! -exec test -e {} \; -delete 2>/dev/null

# 📋 Create LD_LIBRARY_PATH script
cat > run-chrome.sh << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="$DIR/lib:$LD_LIBRARY_PATH"

# Additional environment variables that might help
export GTK_THEME=Adwaita
export FONTCONFIG_PATH=/etc/fonts

exec "$DIR/chrome" "$@"
EOF
chmod +x run-chrome.sh

# 📊 Report results
lib_count=$(find lib -name "*.so*" -type f 2>/dev/null | wc -l)
echo ""
echo "✅ Library extraction complete!"
echo "📊 Found $lib_count library files"
echo "📝 Created run-chrome.sh wrapper script"

# List unique library base names for verification
echo ""
echo "📚 Library summary:"
find lib -name "*.so*" -type f -exec basename {} \; | sed 's/\.so.*//' | sort -u | head -20
echo "..."

# Check Chrome's actual dependencies
echo ""
echo "🔍 Checking which Chrome dependencies are satisfied..."
if [[ -f chrome ]]; then
  ldd chrome 2>/dev/null | grep "not found" | head -10
  if [[ $(ldd chrome 2>/dev/null | grep -c "not found") -eq 0 ]]; then
    echo "✅ All Chrome dependencies appear to be satisfied!"
  else
    missing_count=$(ldd chrome 2>/dev/null | grep -c "not found")
    echo "⚠️ Still missing $missing_count dependencies"
  fi
fi

exit 0