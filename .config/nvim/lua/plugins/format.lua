return {
  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          cpp = { "clang-format" },
          c = { "clang-format" },
          rust = { "rustfmt", lsp_format = "fallback" },
          go = { "gofmt" },
          lua = { "stylua" },
          json = { "biome" },
          jsonc = { "biome" },
          sh = { "shfmt" },
          astro = { "prettier" },
          nix = { "nixfmt" },
          toml = { "taplo" },
          typescript = { "biome" },
          typescriptreact = { "biome" },
          javascript = { "biome" },
          javascriptreact = { "biome" },
          ocaml = { "ocamlformat" },
        },

        formatters = {
          stylua = {
            append_args = {
              "--column-width",
              "100",
              "--indent-type",
              "Spaces",
              "--indent-width",
              "2",
              "--quote-style",
              "AutoPreferDouble",
              "--collapse-simple-statement",
              "Always",
            },
          },
          shfmt = {
            append_args = {
              "-i",
              "2",
            },
          },
          taplo = {
            append_args = {
              "fmt",
              "--option",
              "array_auto_collapse=false",
            },
          },
        },

        format_on_save = {
          timeout_ms = 500,
          lsp_format = "fallback",
        },
      })
    end,
  },
}
