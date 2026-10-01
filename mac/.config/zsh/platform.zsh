# macOS-specific shell setup, sourced by ~/.zshrc

BREW_PREFIX="$(brew --prefix)"

# Configure pnpm
export PNPM_HOME="$HOME/Library/pnpm"

# Locations used by ~/.zshrc for completions and plugins
ZSH_SITE_FUNCTIONS="$BREW_PREFIX/share/zsh/site-functions"
ZSH_PLUGINS_DIR="$BREW_PREFIX/share"

alias sb="brew services restart sketchybar"

# lazygit defaults to ~/Library/Application Support on macOS; use the stowed config
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"
