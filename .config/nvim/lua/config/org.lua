local highlight_group = "OrgItalic"
local emphasis_pattern = [=[\%(^\|\s\|*\|_\|=\|\~\|+\|\$\)\@<=/[^/ \t]\{-1,}/\%(\s\|$\|[[:punct:]]\)\@=]=]
local heading_icon_namespace = vim.api.nvim_create_namespace("OrgHeadingIcons")
local heading_icon_group = vim.api.nvim_create_augroup("OrgHeadingIcons", { clear = true })
local heading_icons = {
  [1] = { icon = "", highlight = "OrgHeadingIcon1" },
  [2] = { icon = "", highlight = "OrgHeadingIcon2" },
  [3] = { icon = "", highlight = "OrgHeadingIcon3" },
  [4] = { icon = "󰛄", highlight = "OrgHeadingIcon4" },
}

local function apply()
  vim.fn.matchadd(highlight_group, emphasis_pattern, 10)
end

local function set_highlight()
  vim.api.nvim_set_hl(0, highlight_group, { italic = true })
  vim.api.nvim_set_hl(0, "OrgHeadingIcon1", { fg = "#56949F" })
  vim.api.nvim_set_hl(0, "OrgHeadingIcon2", { fg = "#56949F" })
  vim.api.nvim_set_hl(0, "OrgHeadingIcon3", { fg = "#907AA9" })
  vim.api.nvim_set_hl(0, "OrgHeadingIcon4", { fg = "#907AA9" })
end

local function subtree_end(lines, start_line, level)
  for line = start_line + 1, #lines do
    local stars = lines[line]:match("^(%*+)%s")
    if stars and #stars <= level then return line - 1 end
  end
  return #lines
end

local function journal_today()
  local journal_path = vim.fn.expand("~/org/journal.org")
  vim.cmd.edit(vim.fn.fnameescape(journal_path))

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local year = os.date("%Y")
  local month = os.date("%Y-%m %B")
  local day = os.date("%Y-%m-%d %A")
  local day_pattern = "^%*%*%* " .. vim.pesc(os.date("%Y-%m-%d"))

  local year_line, month_line, day_line
  for line, text in ipairs(lines) do
    if text == "* " .. year then year_line = line end
    if text == "** " .. month then month_line = line end
    if text:match(day_pattern) then
      day_line = line
      break
    end
  end

  if not day_line then
    if month_line then
      day_line = subtree_end(lines, month_line, 2) + 1
      vim.api.nvim_buf_set_lines(bufnr, day_line - 1, day_line - 1, false, { "*** " .. day, "" })
    elseif year_line then
      day_line = subtree_end(lines, year_line, 1) + 1
      vim.api.nvim_buf_set_lines(bufnr, day_line - 1, day_line - 1, false, { "** " .. month, "*** " .. day, "" })
    else
      day_line = #lines + 1
      vim.api.nvim_buf_set_lines(bufnr, #lines, #lines, false, { "* " .. year, "** " .. month, "*** " .. day, "" })
    end
  end

  vim.api.nvim_win_set_cursor(0, { day_line, 0 })
  vim.cmd("silent! normal! zO")
end

vim.api.nvim_create_user_command("OrgJournalToday", journal_today, {
  desc = "Jump to or create today's journal entry",
})

local function refresh_heading_icons(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, heading_icon_namespace, 0, -1)

  for row, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local stars = line:match("^(%*+)%s")
    local icon = stars and heading_icons[#stars]
    if icon then
      vim.api.nvim_buf_set_extmark(bufnr, heading_icon_namespace, row - 1, 0, {
        end_col = #stars,
        conceal = icon.icon,
        hl_group = icon.highlight,
        priority = 200,
      })
    end
  end
end

set_highlight()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = set_highlight,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "org",
  callback = function(args)
    apply()

    vim.keymap.set("n", "<Leader>oj", journal_today, {
      buffer = args.buf,
      desc = "Jump to today's journal entry",
    })

    vim.wo.conceallevel = 2
    vim.wo.concealcursor = "nvic"
    refresh_heading_icons(args.buf)

    vim.api.nvim_clear_autocmds({ group = heading_icon_group, buffer = args.buf })
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      group = heading_icon_group,
      buffer = args.buf,
      callback = function() refresh_heading_icons(args.buf) end,
    })
  end,
})
