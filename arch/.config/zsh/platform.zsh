# Arch-specific shell setup, sourced by ~/.zshrc

# Configure pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"

# Locations used by ~/.zshrc for completions and plugins
ZSH_SITE_FUNCTIONS="/usr/share/zsh/site-functions"
ZSH_PLUGINS_DIR="/usr/share/zsh/plugins"

export EDITOR="nvim"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$BUN_INSTALL/_bun" ] && fpath=($BUN_INSTALL $fpath)

# Initialize thefuck
command -v thefuck &> /dev/null && eval "$(thefuck --alias)" && alias f="fuck"

# Restart waybar
alias wb="pkill waybar; waybar &!"
