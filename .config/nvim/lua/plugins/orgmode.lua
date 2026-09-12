return {
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    config = function()
      -- Setup orgmode
      require("orgmode").setup({
        org_agenda_files = "~/org/**/*",
        org_default_notes_file = "~/orgfiles/refile.org",
        org_startup_folded = "showeverything",
      })

      local function set_org_keymaps(bufnr)
        vim.keymap.set({ "n", "i" }, "<M-CR>", function()
          require("orgmode").action("org_mappings.insert_heading_respect_content")
        end, {
          buffer = bufnr,
          desc = "Insert sibling heading below current subtree",
        })
      end

      -- The plugin's mapping options apply only in Normal mode.  Define this
      -- explicitly so Alt-Enter also works while writing in Insert mode.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "org",
        callback = function(args) set_org_keymaps(args.buf) end,
      })
      if vim.bo.filetype == "org" then set_org_keymaps(0) end

      -- Experimental LSP support
      vim.lsp.enable("org")
    end,
  },
}
