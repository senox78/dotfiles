#!/usr/bin/env bash
set -eu

input=$1
output=$2
lock=$3
err=$4

tmp="${output}.tmp"
base="${output%.txt}"

mkdir -p "$(dirname "$output")"
rm -f "$err" "$tmp"

cleanup() {
	rm -f "$lock"
}
trap cleanup EXIT HUP INT TERM

if [ -n "${YAZI_TRANSCRIBE_CMD:-}" ]; then
	"$YAZI_TRANSCRIBE_CMD" "$input" "$tmp" 2>"$err"
else
	whisper-cli -f "$input" -otxt -of "$base" 2>"$err"
	[ -f "$base.txt" ] && mv "$base.txt" "$tmp"
fi

if [ -s "$tmp" ]; then
	mv "$tmp" "$output"
	rm -f "$err"
else
	[ -s "$err" ] || printf '%s\n' "transcription produced no output" >"$err"
	rm -f "$tmp"
fi
