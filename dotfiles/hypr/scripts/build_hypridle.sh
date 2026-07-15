#!/usr/bin/env bash
# Script to build hypridle locally without root/sudo privileges.
# Installs it into the hypr/bin/ directory so it's fully self-contained.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_DIR="${HYPR_DIR}/bin"
TEMP_DIR=$(mktemp -d)

# Cleanup on exit/error
trap 'rm -rf "${TEMP_DIR}"' EXIT

echo "Building hypridle locally..."
echo "Temporary build directory: ${TEMP_DIR}"

cd "${TEMP_DIR}"

# 1. Download and extract portable CMake
echo "Downloading portable CMake..."
CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v3.29.3/cmake-3.29.3-linux-x86_64.tar.gz"
curl -sSL "${CMAKE_URL}" | tar -xz
CMAKE_BIN="${TEMP_DIR}/cmake-3.29.3-linux-x86_64/bin/cmake"

# 2. Build hyprland-protocols locally
echo "Cloning and installing hyprland-protocols locally..."
git clone --depth 1 https://github.com/hyprwm/hyprland-protocols.git
cd hyprland-protocols
"${CMAKE_BIN}" -DCMAKE_INSTALL_PREFIX="${TEMP_DIR}/local_install" -S . -B ./build
"${CMAKE_BIN}" --build ./build
"${CMAKE_BIN}" --install ./build
cd "${TEMP_DIR}"

# Set PKG_CONFIG_PATH to include local install
export PKG_CONFIG_PATH="${TEMP_DIR}/local_install/share/pkgconfig:${PKG_CONFIG_PATH:-}"
echo "PKG_CONFIG_PATH set to: ${PKG_CONFIG_PATH}"

# 3. Clone hypridle
echo "Cloning hypridle repository..."
git clone --depth 1 https://github.com/hyprwm/hypridle.git
cd hypridle

# 4. Build hypridle
echo "Building hypridle..."
"${CMAKE_BIN}" --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
"${CMAKE_BIN}" --build ./build --config Release --target hypridle -j"$(nproc)"

# 5. Install binary to hypr/bin/
mkdir -p "${BIN_DIR}"
cp ./build/hypridle "${BIN_DIR}/hypridle"
chmod +x "${BIN_DIR}/hypridle"

echo "hypridle built and installed successfully to: ${BIN_DIR}/hypridle"
