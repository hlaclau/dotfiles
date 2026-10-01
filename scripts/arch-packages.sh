#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/../packages/arch"
AUR_FILE="$PACKAGES_DIR/aur.txt"
PACMAN_FILE="$PACKAGES_DIR/pacman.txt"

# Function to print colored messages
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Please do not run this script as root"
    exit 1
fi

# Check if files exist
if [ ! -f "$PACMAN_FILE" ]; then
    error "pacman.txt not found at $PACMAN_FILE"
    exit 1
fi

if [ ! -f "$AUR_FILE" ]; then
    error "aur.txt not found at $AUR_FILE"
    exit 1
fi

# Check if yay is installed
if ! command -v yay &> /dev/null; then
    warn "yay is not installed. Installing yay-bin first..."
    
    # Check if yay-bin is in the AUR list
    if grep -q "yay-bin" "$AUR_FILE"; then
        info "Installing yay-bin manually..."
        BUILD_DIR="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay-bin.git "$BUILD_DIR"
        cd "$BUILD_DIR"
        makepkg -si --noconfirm
        cd "$SCRIPT_DIR"
        info "yay-bin installed successfully"
    else
        error "yay-bin not found in aur.txt. Please add it or install yay manually."
        exit 1
    fi
fi

info "Installing pacman packages..."
sudo pacman -S --needed --noconfirm $(grep -v '^#' "$PACMAN_FILE" | grep -v '^$' | tr '\n' ' ')

info "Installing AUR packages..."
# Filter out comments and empty lines, then install
yay -S --needed --noconfirm $(grep -v '^#' "$AUR_FILE" | grep -v '^$' | tr '\n' ' ')

info "All packages installed successfully!"
