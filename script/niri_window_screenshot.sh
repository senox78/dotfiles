#!/usr/bin/env bash
# Flatten niri's transparent window capture onto a neutral background.
set -euo pipefail

screenshot_dir="$HOME/Desktop"
screenshot_path="$screenshot_dir/ScreenShot_$(date '+%Y-%m-%d_at_%H.%M.%S').png"
temporary_dir="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/niri-window-screenshot.XXXXXX")"
native_path="$temporary_dir/window.png"

cleanup() {
  rm -rf -- "$temporary_dir"
}
trap cleanup EXIT

mkdir -p "$screenshot_dir"
niri msg action screenshot-window --path "$native_path"
magick "$native_path" -background '#3b3b3b' -alpha remove -alpha off "$screenshot_path"
wl-copy --type image/png < "$screenshot_path"
