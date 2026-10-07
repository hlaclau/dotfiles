# my dotfiles

Dotfiles for macOS and Arch Linux, themed with Catppuccin Mocha. Configs are split into [GNU Stow](https://www.gnu.org/software/stow/) packages, and [mise](https://mise.jdx.dev) tasks stow only the ones the current OS needs.

## Layout

```
shared/     stowed everywhere: zsh, nvim, ghostty, starship, lazygit, fastfetch, btop, bat, mpv, yazi, ideavim
mac/        stowed on macOS:   omniwm, homebrew (Brewfile)
arch/       stowed on Arch:    hyprland, hyprlock, hypridle, hyprpaper, waybar, quickshell, gtk, qt (qt6ct + Kvantum), xsettingsd
packages/   package lists (not stowed): arch/pacman.txt, arch/aur.txt
system/     system files (not stowed): sddm login theme config
scripts/    helper scripts used by the mise tasks
wallpapers/ wallpapers submodule
```

When a tool needs per-OS settings, the shared config includes a `platform` file that `mac/` and `arch/` each provide:

- **zsh**: `shared/.zshrc` sources `~/.config/zsh/platform.zsh` (PNPM path, plugin locations, OS-specific aliases).
- **ghostty**: `shared/.config/ghostty/config` includes `~/.config/ghostty/platform` (font, window decorations, macOS option-as-alt).

macOS is the source of truth: when both systems configure the same tool, the macOS version goes in `shared/`.

## Neovim

`shared/.config/nvim` is a [LazyVim](https://www.lazyvim.org) config with the Catppuccin Mocha colorscheme. Language extras (LSP, treesitter, formatters, linters) are imported in `lua/config/lazy.lua`: Markdown, JavaScript/TypeScript, JSON, Go, Rust, C# and Terraform. Mason installs the language servers on first launch, which needs `node`/`npm`, `go`, `cargo` and `dotnet` on the `PATH` (e.g. through mise). `:LazyHealth` and `:Mason` show what is missing.

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

5. On macOS, set Homebrew's zsh as your shell:

   ```sh
   sudo sh -c 'echo $(brew --prefix)/bin/zsh >> /etc/shells'
   chsh -s $(brew --prefix)/bin/zsh
   ```

## Hyprland desktop

The Arch setup runs Hyprland with a Lua config (`arch/.config/hypr/hyprland.lua`, binds in `bindings.lua`) and a [Quickshell](https://quickshell.org) shell in `arch/.config/quickshell`:

- **Dynamic island** hanging from the top of each screen: clock, now playing, notifications (it replaces a notification daemon), volume popup and a REC timer. `SUPER + I` opens its control center with Home, Audio, Network, Clipboard and Hyprland tabs.
- **Workspace overview** with live window previews: `SUPER + Tab`.
- **App launcher**: a full-screen grid of every app with search, most used first: `SUPER + Space`.
- **Waybar** keeps an empty center for the island.

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
