return {
  -- catppuccin ships with LazyVim, pick the mocha flavour to match the rest of the dotfiles
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "mocha",
      -- start screen colors (sakura pinks)
      custom_highlights = function(c)
        local sakura = "#ffb7c5"
        return {
          DashboardArt = { fg = sakura },
          DashboardTitle = { fg = c.mauve, bold = true },
          SnacksDashboardIcon = { fg = c.mauve },
          SnacksDashboardKey = { fg = sakura, bold = true },
          SnacksDashboardDesc = { fg = c.text },
          SnacksDashboardFooter = { fg = sakura, italic = true },
        }
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      -- "catppuccin" alone resolves to the built-in nvim theme, not the plugin
      colorscheme = "catppuccin-mocha",
    },
  },
}
