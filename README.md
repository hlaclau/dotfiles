# my dotfiles

This repository contains all my dotfiles for macOS, including my Brewfile, configs for zsh, tmux, ghostty, and more.

## Prerequisites

Before you begin, ensure you have the following installed on your macOS system:

- [Homebrew](https://brew.sh)
- [mise](https://mise.jdx.dev)
- Git
- Stow

## Installation

1. Clone this repository to your home directory:

   ```sh
   git clone git@github.com:hlaclau/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

2. Create symbolic links for the dotfiles:

   ```sh
   mise run stow
   ```

   This will symlink all configuration files to their appropriate locations in your home directory.  
   Make sure this step completes successfully — some configurations (like `brew` or `zsh`) might rely on the symlinks being in place before installing packages.

3. Install Homebrew packages and applications:

   ```sh
   mise run brew:install
   ```

   This will install all necessary tools, including:

   - Development tools (neovim, etc.)
   - Shell enhancements (starship, zoxide, fzf)
   - Terminal utilities (bat, eza, btop)
   - Applications (Ghostty, Firefox, Raycast, etc.)
   - Fonts (JetBrains Mono Nerd Font, Geist Mono, Maple Mono)

4. Set up your shell:

   ```sh
   # Add Homebrew's zsh to allowed shells
   sudo sh -c 'echo $(brew --prefix)/bin/zsh >> /etc/shells'

   # Change your default shell to Homebrew's zsh
   chsh -s $(brew --prefix)/bin/zsh
   ```

## Tasks

Managed via [mise](https://mise.jdx.dev). Run `mise tasks` to list all available tasks.

| Task | Description |
|------|-------------|
| `mise run brew:install` | Install packages from Brewfile |
| `mise run stow` | Stow all dotfiles |
| `mise run stow:restow` | Restow all dotfiles (refresh symlinks) |

## Updating

To update your dotfiles and packages:

1. Pull the latest changes:

   ```sh
   cd ~/dotfiles
   git pull
   ```

2. Reapply symlinks if needed:

   ```sh
   mise run stow:restow
   ```

3. Update Homebrew packages:

   ```sh
   mise run brew:install
   ```
