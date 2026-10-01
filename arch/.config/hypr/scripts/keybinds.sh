#!/usr/bin/env bash
# Searchable list of every bind that has a description (see bindings.lua).
set -euo pipefail

hyprctl binds -j | jq -r '
  def mods:
    [ if . % 128 >= 64 then "SUPER" else empty end,
      if . % 8 >= 4 then "CTRL" else empty end,
      if . % 16 >= 8 then "ALT" else empty end,
      if . % 2 >= 1 then "SHIFT" else empty end ];
  .[]
  | select(.has_description)
  | ((.modmask | mods) + [.key | ascii_upcase] | join(" + ")) as $keys
  | "\($keys)  →  \(.description)"
' | vicinae dmenu --navigation-title "Keybinds" --placeholder "Search keybinds" --no-quick-look >/dev/null
