# =============================================================================
#                               PATH CONFIGURATIONS
# =============================================================================

# Add deno completions to search path
if [[ ":$FPATH:" != *":$HOME/.zsh/completions:"* ]]; then export FPATH="$HOME/.zsh/completions:$FPATH"; fi

# Access rust/cargo binaries
export PATH="$HOME/.cargo/bin:$PATH"

# Add Go binaries to PATH
export PATH=$PATH:$HOME/.local/opt/go/bin
export PATH=$PATH:$HOME/go/bin

# Configure pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# =============================================================================
#                               SHELL BEHAVIOR
# =============================================================================

# Initialize zsh completion system
autoload -Uz compinit && compinit

# Add git completion to fpath
if [[ -d "$(brew --prefix)/share/zsh/site-functions" ]]; then
  fpath=($(brew --prefix)/share/zsh/site-functions $fpath)
fi

# Ignore duplicates in history
setopt HIST_IGNORE_ALL_DUPS

# Setup history
export HISTFILE=$HOME/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_VERIFY

# Initialize starship prompt
eval "$(starship init zsh)"

# Initialize zoxide (smart cd)
eval "$(zoxide init zsh)"

# Initialize thefuck
eval $(thefuck --alias)

# Load envman if available
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# =============================================================================
#                               SHELL APPEARANCE
# =============================================================================

# Activate syntax highlighting
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Disable path underline
(( ${+ZSH_HIGHLIGHT_STYLES} )) || typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[path]=none
ZSH_HIGHLIGHT_STYLES[path_prefix]=none

# Activate autosuggestions
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# =============================================================================
#                               FZF CONFIGURATION
# =============================================================================

# Set up fzf key bindings and fuzzy completion
eval "$(fzf --zsh)"

# Configure fzf search commands
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git "
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Configure fzf with vesper colors
export FZF_DEFAULT_OPTS=" \
--height 50% \
--layout=default \
--border \
--color=bg+:#232323,bg:#101010,spinner:#FFC799,hl:#FF8080 \
--color=fg:#ffffff,header:#FF8080,info:#8B8B8B,pointer:#FFC799 \
--color=marker:#99FFE4,fg+:#ffffff,prompt:#FFC799,hl+:#FF8080 \
--color=selected-bg:#353535 \
--color=border:#505050,label:#ffffff"

# Configure fzf previews
export FZF_CTRL_T_OPTS="--preview 'bat --color=always -n --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --long --color=always --icons=always --git {} | head -200'"

# Configure fzf for tmux
export FZF_TMUX_OPTS=" -p90%,70% "

# =============================================================================
#                               ALIASES
# =============================================================================

# Modern replacements for standard commands
alias ls="eza --color=always --icons=always -a"
alias ll="eza --long --color=always --icons=always --git -a"

alias cat="bat"
alias cd="z"
alias n="nvim"
alias g="git"
alias vi="nvim"
alias vim="nvim"

alias glog='git log --oneline --graph --all'

alias lg="lazygit"
alias gh-create='gh repo create --private --source=. --remote=origin && git push -u --all && gh browse'
alias brew-update='brew bundle --file=.config/homebrew/Brewfile'

alias pr="~/scripts/pullrequest.sh"

repo() {
  gh repo view --web
}

# Function for interactive directory selection with eza
fzf-cd() {
  local dir
  dir=$(eza --tree --level=2 --color=always --icons=always | fzf --ansi --preview 'eza --long --color=always --icons=always {}' | sed 's/.* //')
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    cd "$dir"
  fi
}

# Utility aliases
alias cls="clear"
alias h="history 1 | fzf"
alias f="fuck"
alias sb="brew services restart sketchybar"

# source zshrc 
alias reload="source ~/.zshrc"

# =============================================================================
#                               TMUX AUTO-START
# =============================================================================

# Open tmux by default if available and not already in tmux
if command -v tmux &> /dev/null && [ -z "$TMUX" ] && [ -n "$PS1" ] && [[ $- == *i* ]]; then
  tmux attach || tmux
fi

# =============================================================================
#                               FASTFETCH DISPLAY
# =============================================================================

# Show fastfetch only in interactive shells that are not inside tmux
if [[ $- == *i* ]] && [ -z "$TMUX" ]; then
  fastfetch
fi

# =============================================================================
#                               ADDING TOOLS TO PATH
# =============================================================================

# add dotnet tools to path
export PATH="$HOME/.dotnet/tools:$PATH"
export PATH="$HOME/.local/bin:$PATH"

export PATH=$PATH:/Users/hlaclau/.spicetify
