---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  {
    "tiagovla/tokyodark.nvim",
    opts = {},
    config = function(_, opts)
      require("tokyodark").setup(opts)
      vim.cmd [[colorscheme tokyodark]]
    end,
  },
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.cs" },
}
