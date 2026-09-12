return {
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      cmdline = {
        enabled = false,
      },
      -- Noice automatically enables its cmdline handling when messages are
      -- enabled, so disable both to restore Neovim's native command UI.
      messages = {
        enabled = false,
      },
      popupmenu = {
        enabled = false,
      },
      presets = {
        bottom_search = false,
        command_palette = false,
      },
    },
  },
}
