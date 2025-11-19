#!/bin/bash
set -euo pipefail

# RLENV Build Script
# This script rebuilds the application from source located at /rlenv/source/hevcesbrowser/
#
# Original image: ghcr.io/mayhemheroes/hevcesbrowser:master
# Git revision: a22af709a23b1145bf50cf75b4ce3cadafdf074e

# ============================================================================
# Environment Variables
# ============================================================================
export LD_LIBRARY_PATH=/deps

# ============================================================================
# REQUIRED: Change to Source Directory
# ============================================================================
cd /rlenv/source/hevcesbrowser/

# ============================================================================
# Clean Previous Build (recommended)
# ============================================================================
# Remove old build artifacts to ensure fresh rebuild
rm -rf build/

# ============================================================================
# Build Commands (NO NETWORK, NO PACKAGE INSTALLATION)
# ============================================================================
# Create build directory and run CMake + Make
mkdir -p build
cd build
cmake ..
make -j8

# ============================================================================
# Update Runtime Dependencies (if needed)
# ============================================================================
# Re-extract shared libraries for the newly built binary
mkdir -p /deps
ldd /rlenv/source/hevcesbrowser/build/hevcesbrowser_console | tr -s '[:blank:]' '\n' | grep '^/' | xargs -I % sh -c 'cp % /deps;' 2>/dev/null || true

# ============================================================================
# Set Permissions
# ============================================================================
chmod 777 /rlenv/source/hevcesbrowser/build/hevcesbrowser_console 2>/dev/null || true

# ============================================================================
# REQUIRED: Verify Build Succeeded
# ============================================================================
if [ ! -f /rlenv/source/hevcesbrowser/build/hevcesbrowser_console ]; then
    echo "Error: Build artifact not found at /rlenv/source/hevcesbrowser/build/hevcesbrowser_console"
    exit 1
fi

# Verify executable bit
if [ ! -x /rlenv/source/hevcesbrowser/build/hevcesbrowser_console ]; then
    echo "Warning: Build artifact is not executable"
fi

# Verify file size
SIZE=$(stat -c%s /rlenv/source/hevcesbrowser/build/hevcesbrowser_console 2>/dev/null || stat -f%z /rlenv/source/hevcesbrowser/build/hevcesbrowser_console 2>/dev/null || echo 0)
if [ "$SIZE" -lt 1000 ]; then
    echo "Warning: Build artifact is suspiciously small ($SIZE bytes)"
fi

echo "Build completed successfully: /rlenv/source/hevcesbrowser/build/hevcesbrowser_console ($SIZE bytes)"
