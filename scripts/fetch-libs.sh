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
  libgdk-pixbuf-2.0-0
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

# Function to extract package whether installed or not
extract_package() {
  local package=$1
  local success=false
  
  echo "📥 Processing $package..."
  
  # Method 1: Try to download if not installed
  if apt-get download "$package" 2>/dev/null; then
    echo "✅ Downloaded $package (was not installed)"
    success=true
  else
    # Method 2: If package is installed, download it forcefully
    echo "📦 Package might be installed, trying to fetch it..."
    
    # Get the exact version that's installed/available
    version=$(apt-cache policy "$package" | grep -E "Installed:|Candidate:" | head -1 | awk '{print $2}')
    
    if [[ "$version" != "(none)" && -n "$version" ]]; then
      # Try to download using apt-get with reinstall option
      if apt-get download "${package}=${version}" 2>/dev/null; then
        echo "✅ Downloaded $package version $version"
        success=true
      else
        # Method 3: Download directly from package cache or mirrors
        echo "📂 Trying direct fetch from apt cache..."
        
        # Check if it exists in apt cache
        cache_file="/var/cache/apt/archives/${package}_${version}_amd64.deb"
        if [[ -f "$cache_file" ]]; then
          cp "$cache_file" .
          echo "✅ Copied from apt cache"
          success=true
        else
          # Method 4: Force download from repository
          echo "🌐 Downloading from repository..."
          
          # Get the filename from apt-cache
          filename=$(apt-cache show "${package}=${version}" 2>/dev/null | grep "^Filename:" | head -1 | cut -d' ' -f2)
          
          if [[ -n "$filename" ]]; then
            # Try multiple Ubuntu mirrors
            mirrors=(
              "http://archive.ubuntu.com/ubuntu/"
              "http://security.ubuntu.com/ubuntu/"
              "http://azure.archive.ubuntu.com/ubuntu/"
              "http://us.archive.ubuntu.com/ubuntu/"
            )
            
            for mirror in "${mirrors[@]}"; do
              url="${mirror}${filename}"
              if wget -q -O "${package}_${version}_amd64.deb" "$url" 2>/dev/null; then
                echo "✅ Downloaded from $mirror"
                success=true
                break
              fi
            done
          fi
        fi
      fi
    fi
    
    # Method 5: If still no success, try without version specification
    if [[ "$success" == "false" ]]; then
      echo "🔄 Trying without version specification..."
      apt-get download --print-uris "$package" 2>/dev/null | grep "'" | cut -d"'" -f2 | while read -r url; do
        if [[ -n "$url" ]]; then
          filename=$(basename "$url")
          if wget -q -O "$filename" "$url" 2>/dev/null; then
            echo "✅ Downloaded from $url"
            success=true
            break
          fi
        fi
      done
    fi
  fi
  
  # Extract the .deb file if it exists
  deb=$(ls ${package}*.deb 2>/dev/null | head -n1)
  if [[ -f "$deb" ]]; then
    echo "📦 Extracting $deb..."
    dpkg-deb -x "$deb" extract/
    
    # Copy all .so files (including symlinks)
    find extract -name "*.so*" -type f -exec cp -v {} ../lib/ \; 2>/dev/null
    find extract -name "*.so*" -type l -exec cp -av {} ../lib/ \; 2>/dev/null
    
    # Also check for libraries in lib directories
    find extract -path "*/lib/*" -name "*.so*" -exec cp -av {} ../lib/ \; 2>/dev/null
    find extract -path "*/usr/lib/*" -name "*.so*" -exec cp -av {} ../lib/ \; 2>/dev/null
    
    # Clean up extraction
    rm -rf extract/
    rm -f "$deb"
    
    return 0
  else
    echo "⚠️ Could not obtain $package"
    return 1
  fi
}

# Alternative method: Copy from system if package is installed
copy_from_system() {
  local package=$1
  echo "📋 Trying to copy $package libraries from system..."
  
  # Get list of files provided by the package
  if dpkg -L "$package" 2>/dev/null | grep -E "\.so(\.|$)" > /dev/null; then
    dpkg -L "$package" 2>/dev/null | grep -E "\.so(\.|$)" | while read -r lib; do
      if [[ -f "$lib" ]]; then
        cp -L "$lib" ../lib/ 2>/dev/null && echo "  ✅ Copied $(basename "$lib")"
      fi
    done
    return 0
  fi
  return 1
}

# Process each library
failed_packages=()
for lib in "${libs[@]}"; do
  if ! extract_package "$lib"; then
    # If extraction failed, try copying from system
    if ! copy_from_system "$lib"; then
      failed_packages+=("$lib")
    fi
  fi
done

# For failed packages, try one more time with pattern matching
if [[ ${#failed_packages[@]} -gt 0 ]]; then
  echo ""
  echo "🔧 Attempting to resolve failed packages..."
  for package in "${failed_packages[@]}"; do
    echo "🔍 Looking for $package alternatives..."
    
    # Fix common package name variations
    alt_package=""
    case "$package" in
      "libgdk-pixbuf-2.0-0")
        alt_package="libgdk-pixbuf2.0-0"
        ;;
      "libgdk-pixbuf2.0-0")
        alt_package="libgdk-pixbuf-2.0-0"
        ;;
      *)
        # Try to find similar packages
        similar=$(apt-cache search "^${package}" | head -1 | awk '{print $1}')
        if [[ -n "$similar" ]]; then
          alt_package="$similar"
        fi
        ;;
    esac
    
    if [[ -n "$alt_package" ]]; then
      echo "  Trying alternative: $alt_package"
      extract_package "$alt_package" || copy_from_system "$alt_package"
    fi
  done
fi

# 🧹 Clean up
cd ..
rm -rf temp

# 📋 Create LD_LIBRARY_PATH script
cat > chrome-linux/run-chrome.sh << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="$DIR/lib:$LD_LIBRARY_PATH"
exec "$DIR/chrome" "$@"
EOF
chmod +x chrome-linux/run-chrome.sh

# 📊 Report results
lib_count=$(find chrome-linux/lib -name "*.so*" 2>/dev/null | wc -l)
echo ""
echo "✅ Library extraction complete!"
echo "📊 Found $lib_count library files in chrome-linux/lib"
echo "📝 Created run-chrome.sh wrapper script"

# List some of the libraries for verification
echo ""
echo "📚 Sample of extracted libraries:"
ls -la chrome-linux/lib/*.so* 2>/dev/null | head -10

exit 0