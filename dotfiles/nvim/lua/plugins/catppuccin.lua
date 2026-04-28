return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  opts = {
    flavor = vim.g.catppuccin_flavor or "latte",
    transparent_background = false,
    term_colors = true,
    styles = {
      comments = { "italic" },
      functions = {},
      keywords = { "italic" },
      operators = {},
      booleans = {},
    },
    integrations = {
      cmp = true,
      lsp_trouble = true,
      telescope = true,
    },
  },
}