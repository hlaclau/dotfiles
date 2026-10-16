# my dotfiles

Dotfiles for macOS and Arch Linux, themed with Catppuccin Mocha by default and switchable with `mise run theme`. Configs are split into [GNU Stow](https://www.gnu.org/software/stow/) packages, and [mise](https://mise.jdx.dev) tasks stow only the ones the current OS needs.

## Layout

```
shared/     stowed everywhere: zsh, nvim, ghostty, starship, lazygit, fastfetch, btop, bat, mpv, yazi, ideavim
mac/        stowed on macOS:   omniwm, homebrew (Brewfile)
arch/       stowed on Arch:    hyprland, hyprlock, hypridle, hyprpaper, quickshell, gtk, qt (qt6ct + Kvantum), xsettingsd
packages/   package lists (not stowed): arch/pacman.txt, arch/aur.txt
system/     system files (not stowed): sddm login theme config, reflector, zram
scripts/    helper scripts used by the mise tasks
wallpapers/ wallpapers submodule
```

When a tool needs per-OS settings, the shared config includes a `platform` file that `mac/` and `arch/` each provide:

- **zsh**: `shared/.zshrc` sources `~/.config/zsh/platform.zsh` (PNPM path, plugin locations, OS-specific aliases).
- **ghostty**: `shared/.config/ghostty/config` includes `~/.config/ghostty/platform` (font, window decorations, macOS option-as-alt).

macOS is the source of truth: when both systems configure the same tool, the macOS version goes in `shared/`.

## Themes

`mise run theme` lists the themes and `mise run theme <name>` switches to one: Catppuccin (mocha, macchiato, frappe, latte), Rosé Pine (main, moon, dawn), Gruvbox (dark, light), Tokyo Night (night, storm), Nord, Dracula, Everforest and Kanagawa. `mise run stow` applies the current theme (Catppuccin Mocha on a fresh checkout).

- `themes/palettes/<name>.palette` holds the colors of a theme, using the Catppuccin slot names (`base`, `text`, `mauve`, ...). To add a theme, copy a palette and change the hex values.
- The checked-in configs are Catppuccin Mocha. `scripts/theme.sh` swaps every Mocha color for the same slot of the new palette and writes the result to `~/.config/theme/` (starship, lazygit, fastfetch, fzf, ghostty, nvim palette) or to gitignored files in the config dir of tools that only read their own (bat, btop, yazi). `.zshrc` and the ghostty config pick these up and fall back to Mocha when they are missing.
- neovim installs the colorscheme plugin of the current theme on its next start, which updates `lazy-lock.json`.
- Open a new shell for the prompt, lazygit and fzf. ghostty and btop reload on their own, nvim and yazi need a restart.
- On Arch it also themes: quickshell (reads `~/.config/theme/palette.json` and follows changes live), hyprland (borders and shadow, reloaded with `hyprctl reload`), hyprlock (recolored copy, started with `-c`), Kvantum (the Mocha Kvantum theme recolored into the gitignored `theme-current`) and the ghostty cursor trail. SDDM is themed by `mise run arch:sddm`, which recolors its config for the current theme.
- GTK has no palette to swap, so `theme.sh` picks an installed GTK theme that matches (e.g. `catppuccin-<flavor>-mauve-standard+default`, `Gruvbox-Dark`, `Tokyonight-Dark`, `Nordic`, `Dracula`, see `apply_gtk`) and otherwise keeps the current one. Its icons, cursor and wallpaper stay as they are, as does the arch:sddm wallpaper.

## Neovim

`shared/.config/nvim` is a [LazyVim](https://www.lazyvim.org) config with the colorscheme of the current theme (Catppuccin Mocha by default). Language extras (LSP, treesitter, formatters, linters) are imported in `lua/config/lazy.lua`: Markdown, JavaScript/TypeScript, JSON, Go, Rust, C# and Terraform. Mason installs the language servers on first launch, which needs `node`/`npm`, `go`, `cargo` and `dotnet` on the `PATH` (e.g. through mise). `:LazyHealth` and `:Mason` show what is missing.

## Prerequisites

- Git, [Stow](https://www.gnu.org/software/stow/) and [mise](https://mise.jdx.dev)
- macOS: [Homebrew](https://brew.sh)
- Arch: `base-devel` (used to bootstrap `yay`)

## Installation

1. Clone this repository with its submodules into your home directory:

   ```sh
   git clone --recursive git@github.com:hlaclau/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   mise trust
   ```

2. Create the symlinks (`shared` + `mac` or `arch`, picked from the OS). This also fetches the git submodules:

   ```sh
   mise run stow:check   # optional dry run
   mise run stow
   ```

3. Install packages (Brewfile on macOS, pacman + AUR on Arch):

   ```sh
   mise run install
   ```

4. On Arch, apply the login screen theme (needs [SilentSDDM](https://github.com/uiriansan/SilentSDDM) installed):

   ```sh
   mise run arch:sddm
   ```

   Then the system services (mirror refresh, zram, trim, snapper snapshots of a btrfs `/`):

   ```sh
   mise run arch:system
   ```

5. On macOS, set Homebrew's zsh as your shell:

   ```sh
   sudo sh -c 'echo $(brew --prefix)/bin/zsh >> /etc/shells'
   chsh -s $(brew --prefix)/bin/zsh
   ```

## Hyprland desktop

The Arch setup runs Hyprland with a Lua config (`arch/.config/hypr/hyprland.lua`, binds in `bindings.lua`) and a [Quickshell](https://quickshell.org) shell in `arch/.config/quickshell`:

- **Dynamic island** hanging from the top of each screen: clock, now playing, notifications (it replaces a notification daemon), volume popup and a REC timer. `SUPER + I` opens its control center with Home, Audio, Network, Clipboard and Hyprland tabs.
- **Workspace overview** with live window previews: `SUPER + Tab`.
- **Top bar**: a solid strip the island grows out of, with rounded screen corners. Workspaces with app icons, the focused window, weather, CPU/RAM/GPU rings, tray, network/audio/notifications/AI and the date. Hover a chip for details: graphs, a forecast, volume sliders, a calendar.
- **App launcher**: a full-screen grid of every app with search, most used first: `SUPER + Space`. Prefixes switch modes: `=` calc, `>` run, `?` web, `!` ask AI, `:` emoji, `/` files, `@` windows.
- **Wallpaper picker**: your collection plus wallhaven.cc search; downloads go to `~/Pictures/Wallpapers`, and the choice per screen is remembered: `SUPER + W`.
- **Theme picker**: cards with the palette of every theme, Enter or a click applies it with `scripts/theme.sh` (see Themes): `SUPER + SHIFT + W`, or `qs ipc call themes set <id>`.
- **AI chat panel** backed by Claude Code, Codex or Ollama, with preset agents in `agents.json`: `SUPER + C`.

Press `SUPER + /` for a searchable list of every keybind.

Quickshell runs as a systemd user service (`arch/.config/systemd/user/quickshell.service`) so it comes back if it crashes: `systemctl --user restart quickshell` restarts it, `journalctl --user -u quickshell` shows its logs.

## Tasks

Run `mise tasks` to list all available tasks.

| Task | Description |
|------|-------------|
| `mise run submodules` | Fetch git submodules (recursive) |
| `mise run stow` | Fetch submodules, then stow `shared` + the current OS package |
| `mise run stow:restow` | Restow (refresh symlinks) |
| `mise run stow:check` | Dry run: show what stow would do |
| `mise run unstow` | Remove all dotfile symlinks |
| `mise run install` | Install packages for the current OS |
| `mise run brew:install` | Install packages from the Brewfile |
| `mise run arch:install` | Install pacman and AUR packages |
| `mise run arch:sddm` | Apply the Catppuccin config to the SilentSDDM login theme |
| `mise run scripts:macos-utilities` | Apply macOS defaults (Finder, trackpad, keyboard) |

## Updating

```sh
cd ~/dotfiles
git pull
mise run stow:restow   # also updates submodules
mise run install
```
