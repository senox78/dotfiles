-- 選択(なければホバー)中のファイルを GUI クリップボードへ載せる。
-- 実処理は scripts/gui-copy.sh。ここは対象パスの解決と結果表示だけ。
--
-- keymap 例:
--   run = "plugin gui-copy -- auto"   -- 中身、無理なら file:// URI
--   run = "plugin gui-copy -- uri"    -- file:// URI 固定
--   run = "plugin gui-copy -- content" -- 中身固定
--
-- shell の %s を使わないのは、選択が空のとき %s が展開されずコマンド自体が
-- 実行されないため(hover しているだけでは動かない)。

local TITLE = "gui-copy"
local SCRIPT = os.getenv("HOME") .. "/.config/yazi/scripts/gui-copy.sh"

local selected_or_hovered = ya.sync(function()
	local tab, paths = cx.active, {}
	for _, u in pairs(tab.selected) do
		paths[#paths + 1] = tostring(u)
	end
	if #paths == 0 then
		local h = tab.current.hovered
		if h then
			paths[1] = tostring(h.url)
		end
	end
	return paths
end)

local function notify(content, level)
	ya.notify { title = TITLE, content = content, level = level, timeout = 3 }
end

return {
	entry = function(_, job)
		local mode = job.args[1] or "auto"
		if mode ~= "auto" and mode ~= "content" and mode ~= "uri" then
			return notify("unknown mode: " .. tostring(mode), "error")
		end

		local paths = selected_or_hovered()
		if #paths == 0 then
			return notify("コピー対象がありません", "warn")
		end

		local args = { "--" .. mode }
		for _, p in ipairs(paths) do
			args[#args + 1] = p
		end

		local out, err = Command(SCRIPT)
			:arg(args)
			:stdin(Command.NULL)
			:stdout(Command.PIPED)
			:stderr(Command.PIPED)
			:output()

		if err then
			return notify("failed to run gui-copy.sh: " .. tostring(err), "error")
		end

		local msg = (out.status.success and out.stdout or out.stderr):gsub("%s+$", "")
		notify(msg ~= "" and msg or "done", out.status.success and "info" or "error")
	end,
}
