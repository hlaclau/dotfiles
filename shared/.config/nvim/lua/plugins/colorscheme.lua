-- The colorscheme follows the current theme (scripts/theme.sh writes ~/.config/theme/current).
-- Only the plugin of the current theme is declared, lazy.nvim installs it on the next start.
local theme = "catppuccin-mocha"
local f = io.open(vim.fn.expand("~/.config/theme/current"), "r")
if f then
  theme = f:read("*l") or theme
  f:close()
end

local themes = {
  ["catppuccin-mocha"] = { "catppuccin/nvim", name = "catppuccin", opts = { flavour = "mocha" }, colorscheme = "catppuccin-mocha" },
  ["catppuccin-macchiato"] = { "catppuccin/nvim", name = "catppuccin", opts = { flavour = "macchiato" }, colorscheme = "catppuccin-macchiato" },
  ["catppuccin-frappe"] = { "catppuccin/nvim", name = "catppuccin", opts = { flavour = "frappe" }, colorscheme = "catppuccin-frappe" },
  ["catppuccin-latte"] = { "catppuccin/nvim", name = "catppuccin", opts = { flavour = "latte" }, colorscheme = "catppuccin-latte" },
  ["rose-pine"] = { "rose-pine/neovim", name = "rose-pine", opts = { variant = "main" }, colorscheme = "rose-pine-main" },
  ["rose-pine-moon"] = { "rose-pine/neovim", name = "rose-pine", opts = { variant = "moon" }, colorscheme = "rose-pine-moon" },
  ["rose-pine-dawn"] = { "rose-pine/neovim", name = "rose-pine", opts = { variant = "dawn" }, colorscheme = "rose-pine-dawn" },
  ["gruvbox-dark"] = { "ellisonleao/gruvbox.nvim", name = "gruvbox", background = "dark", colorscheme = "gruvbox" },
  ["gruvbox-light"] = { "ellisonleao/gruvbox.nvim", name = "gruvbox", background = "light", colorscheme = "gruvbox" },
  ["tokyo-night"] = { "folke/tokyonight.nvim", name = "tokyonight", opts = { style = "night" }, colorscheme = "tokyonight-night" },
  ["tokyo-night-storm"] = { "folke/tokyonight.nvim", name = "tokyonight", opts = { style = "storm" }, colorscheme = "tokyonight-storm" },
  ["nord"] = { "gbprod/nord.nvim", name = "nord", colorscheme = "nord" },
  ["dracula"] = { "Mofiqul/dracula.nvim", name = "dracula", colorscheme = "dracula" },
  ["everforest-dark"] = { "neanias/everforest-nvim", name = "everforest", main = "everforest", background = "dark", colorscheme = "everforest" },
  ["solarized-dark"] = { "maxmx03/solarized.nvim", name = "solarized", background = "dark", colorscheme = "solarized" },
  ["solarized-light"] = { "maxmx03/solarized.nvim", name = "solarized", background = "light", colorscheme = "solarized" },
  ["one-dark"] = { "navarasu/onedark.nvim", name = "onedark", opts = { style = "dark" }, colorscheme = "onedark" },
  ["github-dark"] = { "projekt0n/github-nvim-theme", name = "github-theme", colorscheme = "github_dark" },
  ["ayu-mirage"] = { "Shatur/neovim-ayu", name = "ayu", opts = { mirage = true }, colorscheme = "ayu-mirage" },
  ["nightfox"] = { "EdenEast/nightfox.nvim", name = "nightfox", colorscheme = "nightfox" },
  ["poimandres"] = { "olivercederborg/poimandres.nvim", name = "poimandres", colorscheme = "poimandres" },
  ["monokai"] = { "tanvirtin/monokai.nvim", name = "monokai", main = "monokai", colorscheme = "monokai" },
  ["kanagawa-wave"] = { "rebelot/kanagawa.nvim", name = "kanagawa", opts = { theme = "wave" }, colorscheme = "kanagawa-wave" },
}

local t = themes[theme] or themes["catppuccin-mocha"]

-- start screen colors (sakura pinks) on top of whatever colorscheme is active
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    local ok, p = pcall(dofile, vim.fn.expand("~/.config/theme/palette.lua"))
    if not ok then
      return
    end
    local sakura = "#ffb7c5"
    local set = vim.api.nvim_set_hl
    set(0, "DashboardArt", { fg = sakura })
    set(0, "DashboardTitle", { fg = p.accent, bold = true })
    set(0, "SnacksDashboardIcon", { fg = p.accent })
    set(0, "SnacksDashboardKey", { fg = sakura, bold = true })
    set(0, "SnacksDashboardDesc", { fg = p.text })
    set(0, "SnacksDashboardFooter", { fg = sakura, italic = true })
  end,
})

return {
  {
    t[1],
    name = t.name,
    main = t.main,
    priority = 1000,
    opts = t.opts or {},
    init = function()
      if t.background then
        vim.o.background = t.background
      end
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      -- "catppuccin" alone resolves to the built-in nvim theme, so use the full flavour name
      colorscheme = t.colorscheme,
    },
  },
}
