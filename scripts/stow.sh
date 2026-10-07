#!/usr/bin/env bash
# Stow the shared package plus the one for the current OS into $HOME.
# Extra arguments are passed to stow (e.g. --restow, --delete, --simulate).
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$(uname -s)" in
  Darwin) platform="mac" ;;
  Linux) platform="arch" ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac

echo "Stowing shared + $platform"
# mise.toml files are never stowed
stow --dir "$DOTFILES" --target "$HOME" --ignore='mise\.toml' "$@" shared "$platform"
