#!/usr/bin/env bash
# Apply the Catppuccin config to the SilentSDDM login theme.
# Copies system/sddm/silent-catppuccin.conf and the wallpaper into the theme
# and points the theme at that config. Needs sudo; run it again after changes.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME=/usr/share/sddm/themes/silent
CONFIG="$DOTFILES/system/sddm/silent-catppuccin.conf"
WALLPAPER="$DOTFILES/wallpapers/frieren-catppuccin.png"

if [ ! -d "$THEME" ]; then
  echo "SilentSDDM is not installed at $THEME" >&2
  exit 1
fi
if [ ! -f "$WALLPAPER" ]; then
  echo "Missing $WALLPAPER (run: mise run submodules)" >&2
  exit 1
fi

sudo install -m 644 "$CONFIG" "$THEME/configs/silent-catppuccin.conf"
sudo install -m 644 "$WALLPAPER" "$THEME/backgrounds/frieren-catppuccin.png"
sudo sed -i 's|^ConfigFile=.*|ConfigFile=configs/silent-catppuccin.conf|' "$THEME/metadata.desktop"

echo "SDDM theme updated. Preview it with: cd $THEME && ./test.sh"
