return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  version = false,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    provider = "opencode",
    acp_providers = {
      opencode = {
        command = "opencode",
        args = { "acp" },
      },
    },
  },
}
