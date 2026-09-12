return {
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "mfussenegger/nvim-dap",
    },
    config = function()
      require("mason-nvim-dap").setup({
        ensure_installed = { "codelldb" },
      })
    end,
  },
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require("dap")

      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = "codelldb",
          args = { "--port", "${port}" },
        },
      }

      -- local debug = {}
      -- pcall(function() debug = dofile(vim.fn.getcwd() .. "/.nvim/debug.lua") end)

      dap.configurations.rust = {
        {
          name = "Launch Rust",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
          end,
          cwd = "${workspaceFolder}",
          args = function()
            local ok, result = pcall(dofile, vim.fn.getcwd() .. "/.nvim/debug.lua")
            if ok and type(result) == "table" then return result.args or {} end
            return {}
          end,
          stopOnEntry = false,
        },
      }

      vim.keymap.set("n", "<F5>", dap.continue)
      vim.keymap.set("n", "<F10>", dap.step_over)
      vim.keymap.set("n", "<F11>", dap.step_into)
      vim.keymap.set("n", "<F12>", dap.step_out)
      vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint)
      vim.keymap.set("n", "<C-b>", dap.toggle_breakpoint)
      vim.keymap.set("n", "<leader>dr", dap.repl.open)
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()

      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end

      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end

      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
    end,
  },
}
