-- Copyright (c) 2026 Uliboooo. All Rights Reserved.
-- SPDX-License-Identifier: MIT

-- vim-smartchr-like input helper
-- Repeatedly pressing the same key cycles through a list of candidates.
--   |    -> "|"
--   ||   -> " |> "
--   |||  -> " || "
-- When a candidate begins with whitespace, the preceding whitespace is
-- consumed to avoid duplication. Indentation is left untouched.

local M = {}

local last = { id = nil, buf = nil, row = nil, col = nil, nth = nil, text = nil }

--- @param cands string[] 1 回目, 2 回目, ... の候補
--- @return function
function M.loop(cands)
  local id = {}

  return function()
    local buf = vim.api.nvim_get_current_buf()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()

    local nth, removed = 1, ""
    if last.id == id and last.buf == buf and last.row == row and last.col == col then
      if line:sub(col - #last.text + 1, col) == last.text then
        nth = last.nth % #cands + 1
        removed = last.text
      end
    end

    local cand = cands[nth]
    local before = line:sub(1, col - #removed)
    local eaten = ""

    if cand:sub(1, 1) == " " then
      if before:match("%S") then
        eaten = before:match("[ \t]*$") or "" -- 既にある空白を食べて入れ直す
      else
        cand = cand:gsub("^ +", "") -- 行頭・インデント直後では先頭の空白は付けない
      end
    end

    local from = col - #removed - #eaten
    vim.api.nvim_buf_set_text(buf, row - 1, from, row - 1, col, { cand })
    vim.api.nvim_win_set_cursor(0, { row, from + #cand })

    last = { id = id, buf = buf, row = row, col = from + #cand, nth = nth, text = cand }
  end
end

--- @param bufnr integer
--- @param maps table<string, string[]> キー -> 候補
function M.set(bufnr, maps)
  for key, cands in pairs(maps) do
    vim.keymap.set("i", key, M.loop(cands), {
      buffer = bufnr,
      desc = "smartchr: " .. table.concat(cands, " / "),
    })
  end
end

-- filetype ごとの設定
local specs = {
  {
    ft = { "ocaml", "reason", "fsharp", "elixir", "gleam", "elm", "julia", "r" },
    maps = {
      ["|"] = { "|", " |> ", " || " },
    },
  },
}

local group = vim.api.nvim_create_augroup("smartchr", { clear = true })
for _, spec in ipairs(specs) do
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = spec.ft,
    callback = function(ev) M.set(ev.buf, spec.maps) end,
  })
end

return M
