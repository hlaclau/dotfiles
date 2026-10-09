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

# CLT 26.6's linker can't read the MacOSX27 SDK (breaks tree-sitter parser builds);
# pin to 26.5 until CLT 27 is installed, then remove this
_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
[[ -d "$_sdk" ]] && export SDKROOT="$_sdk"
unset _sdk
