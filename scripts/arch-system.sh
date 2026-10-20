#!/usr/bin/env bash
# Apply the system-level setup for Arch: mirror refresh, zram swap, SSD trim,
# package cache cleanup, btrfs snapshots of / with snapper.
# Copies the files in system/ to /etc and enables the timers. Needs sudo;
# safe to run again.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sudo pacman -S --needed --noconfirm reflector pacman-contrib zram-generator snapper

sudo install -Dm 644 "$DOTFILES/system/reflector/reflector.conf" /etc/xdg/reflector/reflector.conf
sudo install -Dm 644 "$DOTFILES/system/zram/zram-generator.conf" /etc/systemd/zram-generator.conf
sudo install -Dm 644 "$DOTFILES/system/udev/71-razer-hidraw.rules" /etc/udev/rules.d/71-razer-hidraw.rules
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=hidraw

# Remove the Chrome theme policy left by older versions of this script (it makes Chrome show "managed by your organization")
sudo rm -rf /etc/opt/chrome/policies/managed/theme.json
THEME_NO_WALLPAPER=1 "$DOTFILES/scripts/theme.sh" apply

sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service || true
sudo systemctl enable --now reflector.timer fstrim.timer paccache.timer

# Snapshots need a btrfs root
if [ "$(findmnt -no FSTYPE /)" = btrfs ]; then
  if ! sudo snapper list-configs | grep -qw root; then
    sudo snapper -c root create-config /
  fi
  sudo snapper -c root set-config TIMELINE_LIMIT_HOURLY=5 TIMELINE_LIMIT_DAILY=7 \
    TIMELINE_LIMIT_WEEKLY=2 TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0
  sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
else
  echo "Root is not btrfs, skipping snapper" >&2
fi

echo "System setup applied."
