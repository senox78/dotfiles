local M = {}

local CACHE_DIR = os.getenv("HOME") .. "/.cache/yazi/transcribe"
local SCRIPT = os.getenv("HOME") .. "/.config/yazi/scripts/transcribe-wav.sh"

local function path_for(file)
	return tostring(file.url.path)
end

local function cache_paths(file)
	local cha = file.cha
	local key = table.concat({
		path_for(file),
		tostring(cha and cha.len or 0),
		tostring(cha and cha.mtime or 0),
	}, "\0")
	local hash = ya.hash(key)

	return {
		txt = CACHE_DIR .. "/" .. hash .. ".txt",
		lock = CACHE_DIR .. "/" .. hash .. ".lock",
		err = CACHE_DIR .. "/" .. hash .. ".err",
	}
end

local function output(path)
	return Command("sh")
		:arg({ "-c", 'if [ -s "$1" ]; then cat "$1"; fi', "sh", path })
		:stdout(Command.PIPED)
		:stderr(Command.NULL)
		:output()
end

local function read_nonempty(path)
	local out, err = output(path)
	if err or not out or not out.status.success or out.stdout == "" then
		return nil
	end
	return out.stdout
end

local function exists(path)
	local out, err = Command("sh")
		:arg({ "-c", 'test -e "$1"', "sh", path })
		:stdout(Command.NULL)
		:stderr(Command.NULL)
		:output()
	return not err and out and out.status.success
end

local function preview(job, lines)
	ya.preview_widget(job, ui.Text(lines):area(job.area):wrap(ui.Wrap.YES))
end

local function start_transcribe(file, paths)
	local input = path_for(file)
	local status, err = Command("sh")
		:arg({
			"-c",
			'mkdir -p "$1" && : > "$2" && "$3" "$4" "$5" "$2" "$6" </dev/null >/dev/null 2>/dev/null &',
			"sh",
			CACHE_DIR,
			paths.lock,
			SCRIPT,
			input,
			paths.txt,
			paths.err,
		})
		:stdin(Command.NULL)
		:stdout(Command.NULL)
		:stderr(Command.NULL)
		:status()

	if err then
		ya.err("wav-transcribe: failed to start: " .. tostring(err))
	elseif not status.success then
		ya.err("wav-transcribe: start command exited with " .. tostring(status.code))
	end
end

function M:peek(job)
	local paths = cache_paths(job.file)

	local text = read_nonempty(paths.txt)
	if text then
		preview(job, text)
		return
	end

	local err = read_nonempty(paths.err)
	if err then
		preview(job, {
			ui.Line("Transcription failed"):fg("red"):bold(),
			ui.Line(""),
			ui.Line(err),
		})
		return
	end

	if not exists(paths.lock) then
		start_transcribe(job.file, paths)
	end

	preview(job, {
		ui.Line("Transcribing..."):fg("yellow"):bold(),
		ui.Line(""),
		ui.Line("Hover this file again after the background job finishes."),
	})
end

function M:seek(job)
	ya.emit("peek", { 0, only_if = job.file.url })
end

return M
