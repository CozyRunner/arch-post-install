# 💤 Neovim Configuration (LazyVim)

A modern, high-performance [Neovim](https://neovim.io) setup powered by [LazyVim](https://lazyvim.github.io), tailored for fast startup, comprehensive LSP code intelligence, and seamless integration with the desktop theming engine.

---

## 🚀 Key Features

- ⚡ **Blazing Fast**: Modular plugin management via [lazy.nvim](https://github.com/folke/lazy.nvim) with lazy-loading on demand.
- 🔍 **Fuzzy Finding**: [Telescope](https://github.com/nvim-telescope/telescope.nvim) and [Fzf-Lua](https://github.com/ibhagwan/fzf-lua) for lightning-fast file, buffer, and symbol searches.
- 💡 **IDE Intelligence**: Built-in LSP support with automated Mason installer, autocompletion via `nvim-cmp` or `blink.cmp`, and rich diagnostics.
- 🌲 **Tree-sitter**: Modern syntax highlighting and AST-based code motions for all major languages.
- 🎨 **Adaptive Theming**: Synchronized with desktop theme palettes (Catppuccin, Tokyo Night, Gruvbox, etc.).
- 📁 **File Explorer**: [Neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim) with git status indicators and file operations.
- ⌨️ **Keybind Discovery**: [Which-Key](https://github.com/folke/which-key.nvim) for real-time popup keybinding hints.

---

## 📂 Directory Structure

```
~/.config/nvim/
├── init.lua                 # Entry point loading lazy.nvim
├── lazy-lock.json           # Exact lockfile for reproducible plugin versions
├── lazyvim.json             # LazyVim state & extras configuration
│
└── lua/
    ├── config/
    │   ├── autocmds.lua     # Custom autocommands
    │   ├── keymaps.lua      # Custom user key mappings
    │   ├── lazy.lua         # LazyVim bootstrap & options
    │   └── options.lua      # Vim option overrides (tabstop, line numbers, etc.)
    │
    └── plugins/             # Custom plugin specs & overrides
        ├── example.lua      # Plugin override examples
        └── ...
```

---

## ⌨️ Essential Keybindings

| Keybinding | Mode | Action |
|---|---|---|
| `<leader>` | Normal | **Spacebar** (Leader key) |
| `<leader>e` | Normal | Toggle File Explorer (Neo-tree) |
| `<leader>ff` | Normal | Find Files (Telescope) |
| `<leader>fg` / `<leader>sg` | Normal | Live Grep in Codebase |
| `<leader>fb` / `<leader><space>` | Normal | Find Open Buffers |
| `<leader>cf` | Normal | Format Document (conform.nvim / LSP) |
| `<leader>ca` | Normal | Code Action at cursor |
| `<leader>cr` | Normal | Rename Symbol (LSP) |
| `gd` | Normal | Goto Definition |
| `gr` | Normal | Goto References |
| `K` | Normal | Hover Documentation |
| `<leader>bd` | Normal | Close Active Buffer |
| `<leader>qq` | Normal | Quit Neovim |
| `<leader>l` | Normal | Open Lazy Plugin Manager |
| `<leader>m` | Normal | Open Mason Package Manager |

---

## 🧩 Managing Plugins & Language Servers

- **Update Plugins**: Run `:Lazy` and press `U` or run `:Lazy update`.
- **Install LSPs / Formatters**: Run `:Mason` to browse and install language servers, linters, and formatters.
- **Health Check**: Run `:checkhealth` to verify all dependencies and clipboard integration.
