return {
  {
    "nvim-mini/mini.pairs",
    version = false,
    config = function() require("mini.pairs").setup() end,
  },

  {
    "windwp/nvim-ts-autotag",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },

  {
    "nvim-mini/mini.comment",
    version = false,
    config = function()
      local comment = require("mini.comment")

      comment.setup()

      -- ctrl+c
      vim.keymap.set("n", "<C-c>", function()
        local line = vim.fn.line(".")
        comment.toggle_lines(line, line)
      end, { desc = "toggle current line comment" })

      vim.keymap.set("x", "<C-c>", function()
        local start_line = vim.fn.line("v")
        local end_line = vim.fn.line(".")

        if start_line > end_line then
          start_line, end_line = end_line, start_line
        end

        comment.toggle_lines(start_line, end_line)
      end, { desc = "toggle selected comment" })
    end,
  },
}
