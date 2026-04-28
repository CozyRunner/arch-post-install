-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.g.catppuccin_flavor = "latte"

local function toggle_catppuccin_theme()
  vim.g.catppuccin_flavor = vim.g.catppuccin_flavor == "latte" and "mocha" or "latte"
  require("catppuccin").setup({
    flavor = vim.g.catppuccin_flavor,
  })
  vim.cmd.colorscheme("catppuccin")
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    require("catppuccin").setup({
      flavor = vim.g.catppuccin_flavor,
    })
    vim.cmd.colorscheme("catppuccin")
  end,
})

vim.keymap.set("n", "<leader>ts", toggle_catppuccin_theme, { desc = "Toggle catppuccin theme" })
