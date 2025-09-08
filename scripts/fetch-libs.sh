#!/bin/bash

# This script copies libraries directly from the system
# Handles both old package names and new t64 variants (Ubuntu 24.04+)

echo "📦 Library extraction - copying from installed system packages"

# ✅ Create target lib directory
mkdir -p chrome-linux/lib
cd chrome-linux || exit 1

# 📦 List of required packages (with both old and new t64 variants)
packages=(
  # ATK packages
  libatk1.0-0
  libatk1.0-0t64
  libatk-bridge2.0-0
  libatk-bridge2.0-0t64
  
  # Core libraries
  libcups2
  libcups2t64
  libgbm1
  libgtk-3-0
  libgtk-3-0t64
  libasound2
  libasound2t64
  libnss3
  libxshmfence1
  libdrm2
  libdbus-1-3
  libglib2.0-0
  libglib2.0-0t64
  libgdk-pixbuf-2.0-0
  libgdk-pixbuf2.0-0
  libpango-1.0-0
  libpangocairo-1.0-0
  libcurl4
  libcurl4t64
  
  # X11 libraries
  libxcomposite1
  libxdamage1
  libxrandr2
  libx11-6
  libxext6
  libexpat1
  libxi6
  libxrender1
  
  # Cairo and related
  libcairo2
  libudev1
  libpcre3
  libxcb1
  libxkbcommon0
  
  # Accessibility
  libatspi2.0-0
  libatspi2.0-0t64
  
  # Avahi
  libavahi-common3
  libavahi-client3
)

# First, try to install packages (will skip already installed ones)
echo "📥 Ensuring required packages are installed..."
apt-get update >/dev/null 2>&1

# Install packages, ignoring errors for non-existent package names
for pkg in "${packages[@]}"; do
  apt-get install -y "$pkg" 2>/dev/null || true
done

echo ""
echo "📋 Copying libraries from installed packages..."

# Function to copy libraries from a package
copy_package_libs() {
  local pkg=$1
  
  # Check if package is installed
  if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
    echo "  ✅ Processing $pkg..."
    
    # Get libraries from dpkg file list
    dpkg -L "$pkg" 2>/dev/null | while read -r file; do
      if [[ "$file" =~ \.so($|\.) ]]; then
        if [[ -f "$file" ]]; then
          # Copy the actual file (following symlinks)
          cp -L "$file" lib/ 2>/dev/null
          # Also copy the symlink itself to preserve library naming
          cp -P "$file" lib/ 2>/dev/null
        fi
      fi
    done
    return 0
  fi
  return 1
}

# Process each package, trying both regular and t64 variants
processed_packages=()
skipped_packages=()

for package in "${packages[@]}"; do
  # Skip if we've already processed a variant of this package
  base_name="${package%t64}"
  if [[ " ${processed_packages[@]} " =~ " ${base_name} " ]]; then
    continue
  fi
  
  if copy_package_libs "$package"; then
    processed_packages+=("$base_name")
  else
    # If this package isn't found, don't report it if we already found its variant
    if [[ ! " ${processed_packages[@]} " =~ " ${base_name} " ]]; then
      # Only add to skipped if it's not a t64 variant
      if [[ ! "$package" =~ t64$ ]]; then
        skipped_packages+=("$package")
      fi
    fi
  fi
done

# Report skipped packages
if [[ ${#skipped_packages[@]} -gt 0 ]]; then
  echo ""
  echo "⚠️  Packages not found (may have t64 variants installed instead):"
  for pkg in "${skipped_packages[@]}"; do
    echo "    - $pkg"
  done
fi

echo ""
echo "📋 Copying additional essential libraries..."

# Function to safely copy libraries with glob patterns
copy_libs_pattern() {
  local pattern=$1
  for file in $pattern; do
    if [[ -f "$file" ]]; then
      # Copy the actual file (following symlinks)
      cp -L "$file" lib/ 2>/dev/null
      # Also copy symlinks to preserve library naming
      if [[ -L "$file" ]]; then
        cp -P "$file" lib/ 2>/dev/null
      fi
    fi
  done
}

# Copy essential runtime libraries that Chrome needs
essential_patterns=(
  # C/C++ runtime
  "/usr/lib/x86_64-linux-gnu/libstdc++.so*"
  "/usr/lib/x86_64-linux-gnu/libgcc_s.so*"
  "/lib/x86_64-linux-gnu/libm.so*"
  "/lib/x86_64-linux-gnu/libm-*.so*"
  "/lib/x86_64-linux-gnu/libdl.so*"
  "/lib/x86_64-linux-gnu/libdl-*.so*"
  "/lib/x86_64-linux-gnu/libpthread.so*"
  "/lib/x86_64-linux-gnu/libpthread-*.so*"
  "/lib/x86_64-linux-gnu/librt.so*"
  "/lib/x86_64-linux-gnu/librt-*.so*"
  "/lib/x86_64-linux-gnu/libc.so*"
  "/lib/x86_64-linux-gnu/libc-*.so*"
  "/lib/x86_64-linux-gnu/libresolv.so*"
  "/lib/x86_64-linux-gnu/libresolv-*.so*"
  
  # Graphics related
  "/usr/lib/x86_64-linux-gnu/libGL.so*"
  "/usr/lib/x86_64-linux-gnu/libEGL.so*"
  "/usr/lib/x86_64-linux-gnu/libGLESv2.so*"
  "/usr/lib/x86_64-linux-gnu/libGLX.so*"
  "/usr/lib/x86_64-linux-gnu/libGLdispatch.so*"
  
  # X11 and display related
  "/usr/lib/x86_64-linux-gnu/libX*.so*"
  
  # GTK and dependencies
  "/usr/lib/x86_64-linux-gnu/libgtk-3.so*"
  "/usr/lib/x86_64-linux-gnu/libgdk-3.so*"
  "/usr/lib/x86_64-linux-gnu/libcairo*.so*"
  "/usr/lib/x86_64-linux-gnu/libpango*.so*"
  "/usr/lib/x86_64-linux-gnu/libharfbuzz*.so*"
  "/usr/lib/x86_64-linux-gnu/libgobject*.so*"
  "/usr/lib/x86_64-linux-gnu/libglib*.so*"
  "/usr/lib/x86_64-linux-gnu/libgio*.so*"
  "/usr/lib/x86_64-linux-gnu/libgmodule*.so*"
  "/usr/lib/x86_64-linux-gnu/libgthread*.so*"
  "/usr/lib/x86_64-linux-gnu/libatk*.so*"
  
  # NSS/NSPR
  "/usr/lib/x86_64-linux-gnu/libnss*.so*"
  "/usr/lib/x86_64-linux-gnu/libnspr*.so*"
  "/usr/lib/x86_64-linux-gnu/libplc*.so*"
  "/usr/lib/x86_64-linux-gnu/libplds*.so*"
  "/usr/lib/x86_64-linux-gnu/libsmime*.so*"
  "/usr/lib/x86_64-linux-gnu/libssl*.so*"
  
  # Other important libraries
  "/usr/lib/x86_64-linux-gnu/libcups.so*"
  "/usr/lib/x86_64-linux-gnu/libasound.so*"
  "/usr/lib/x86_64-linux-gnu/libpulse*.so*"
  "/usr/lib/x86_64-linux-gnu/libdbus*.so*"
  "/usr/lib/x86_64-linux-gnu/libexpat*.so*"
  "/usr/lib/x86_64-linux-gnu/libfontconfig*.so*"
  "/usr/lib/x86_64-linux-gnu/libfreetype*.so*"
  "/usr/lib/x86_64-linux-gnu/libz.so*"
  "/usr/lib/x86_64-linux-gnu/libpng*.so*"
  "/usr/lib/x86_64-linux-gnu/libjpeg*.so*"
  "/usr/lib/x86_64-linux-gnu/libxcb*.so*"
  "/usr/lib/x86_64-linux-gnu/libxkb*.so*"
  "/usr/lib/x86_64-linux-gnu/libwayland*.so*"
  "/usr/lib/x86_64-linux-gnu/libffi*.so*"
  "/usr/lib/x86_64-linux-gnu/libpcre*.so*"
  "/usr/lib/x86_64-linux-gnu/libuuid*.so*"
  "/usr/lib/x86_64-linux-gnu/libmount*.so*"
  "/usr/lib/x86_64-linux-gnu/libblkid*.so*"
  "/usr/lib/x86_64-linux-gnu/libselinux*.so*"
  "/usr/lib/x86_64-linux-gnu/libgraphite*.so*"
  "/usr/lib/x86_64-linux-gnu/libbrotli*.so*"
  "/usr/lib/x86_64-linux-gnu/libbz2*.so*"
  "/usr/lib/x86_64-linux-gnu/libdatrie*.so*"
  "/usr/lib/x86_64-linux-gnu/libthai*.so*"
  "/usr/lib/x86_64-linux-gnu/libpixman*.so*"
  "/usr/lib/x86_64-linux-gnu/libxcb-shm*.so*"
  "/usr/lib/x86_64-linux-gnu/libxcb-render*.so*"
  "/usr/lib/x86_64-linux-gnu/libudev*.so*"
  "/usr/lib/x86_64-linux-gnu/libgbm*.so*"
  "/usr/lib/x86_64-linux-gnu/libdrm*.so*"
  "/usr/lib/x86_64-linux-gnu/libcurl*.so*"
  "/usr/lib/x86_64-linux-gnu/libnghttp*.so*"
  "/usr/lib/x86_64-linux-gnu/libidn*.so*"
  "/usr/lib/x86_64-linux-gnu/librtmp*.so*"
  "/usr/lib/x86_64-linux-gnu/libssh*.so*"
  "/usr/lib/x86_64-linux-gnu/libpsl*.so*"
  "/usr/lib/x86_64-linux-gnu/libgssapi*.so*"
  "/usr/lib/x86_64-linux-gnu/libldap*.so*"
  "/usr/lib/x86_64-linux-gnu/liblber*.so*"
  "/usr/lib/x86_64-linux-gnu/libsasl*.so*"
  "/usr/lib/x86_64-linux-gnu/libgnutls*.so*"
  "/usr/lib/x86_64-linux-gnu/libhogweed*.so*"
  "/usr/lib/x86_64-linux-gnu/libnettle*.so*"
  "/usr/lib/x86_64-linux-gnu/libgmp*.so*"
  "/usr/lib/x86_64-linux-gnu/libtasn*.so*"
  "/usr/lib/x86_64-linux-gnu/libp11*.so*"
  "/usr/lib/x86_64-linux-gnu/libkrb*.so*"
  "/usr/lib/x86_64-linux-gnu/libk5*.so*"
  "/usr/lib/x86_64-linux-gnu/libcom_err*.so*"
  "/usr/lib/x86_64-linux-gnu/libkeyutils*.so*"
)

for pattern in "${essential_patterns[@]}"; do
  copy_libs_pattern "$pattern"
done

# Also check alternative library locations
alt_lib_dirs=(
  "/lib/x86_64-linux-gnu"
  "/lib64"
  "/usr/lib64"
  "/usr/local/lib"
  "/usr/local/lib64"
)

for dir in "${alt_lib_dirs[@]}"; do
  if [[ -d "$dir" ]]; then
    # Copy any .so files that might be needed
    find "$dir" -maxdepth 1 -name "*.so*" -type f 2>/dev/null | while read -r lib; do
      base_name=$(basename "$lib")
      if [[ ! -f "lib/$base_name" ]]; then
        cp -L "$lib" lib/ 2>/dev/null
      fi
    done
  fi
done

# Remove any broken symlinks
find lib -type l ! -exec test -e {} \; -delete 2>/dev/null

# Create LD_LIBRARY_PATH script
cat > run-chrome.sh << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="$DIR/lib:$LD_LIBRARY_PATH"

# Additional environment variables that might help
export GTK_THEME=Adwaita
export FONTCONFIG_PATH=/etc/fonts

# Disable sandbox if running as root or in container
if [ "$EUID" -eq 0 ] || [ -f /.dockerenv ] || [ -n "$KUBERNETES_SERVICE_HOST" ]; then
  exec "$DIR/chrome" --no-sandbox "$@"
else
  exec "$DIR/chrome" "$@"
fi
EOF
chmod +x run-chrome.sh

# 📊 Report results
lib_count=$(find lib -name "*.so*" -type f 2>/dev/null | wc -l)
symlink_count=$(find lib -name "*.so*" -type l 2>/dev/null | wc -l)
echo ""
echo "✅ Library extraction complete!"
echo "📊 Found $lib_count library files and $symlink_count symlinks"
echo "📝 Created run-chrome.sh wrapper script"

# List unique library base names for verification
echo ""
echo "📚 Sample of extracted libraries:"
find lib -name "*.so*" -type f -exec basename {} \; | sed 's/\.so.*//' | sort -u | head -20

# Check Chrome's actual dependencies
echo ""
echo "🔍 Checking which Chrome dependencies are satisfied..."
if [[ -f chrome ]]; then
  missing_libs=$(ldd chrome 2>/dev/null | grep "not found" | awk '{print $1}' | sort -u)
  if [[ -z "$missing_libs" ]]; then
    echo "✅ All Chrome dependencies appear to be satisfied!"
  else
    echo "⚠️  Still missing these libraries:"
    echo "$missing_libs" | head -10
    missing_count=$(echo "$missing_libs" | wc -l)
    if [[ $missing_count -gt 10 ]]; then
      echo "... and $((missing_count - 10)) more"
    fi
    
    echo ""
    echo "💡 Attempting to find missing libraries in the system..."
    echo "$missing_libs" | while read -r missing_lib; do
      found_lib=$(find /usr/lib /lib -name "$missing_lib" 2>/dev/null | head -1)
      if [[ -n "$found_lib" ]]; then
        echo "  Found $missing_lib at $found_lib - copying..."
        cp -L "$found_lib" lib/ 2>/dev/null
        cp -P "$found_lib" lib/ 2>/dev/null
      fi
    done
  fi
fi

exit