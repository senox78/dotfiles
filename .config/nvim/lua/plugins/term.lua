return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        shell = "fish",
        direction = "float",

        float_opts = {
          border = "curved",
          width = function() return vim.o.columns - 7 end,
          height = function() return vim.o.lines - 5 end,
        },
      })

      -- Toggle terminal
      vim.keymap.set(
        { "n", "t" },
        "<C-\\>",
        function() vim.cmd("ToggleTerm") end,
        { noremap = true, silent = true }
      )
    end,
  },
}
