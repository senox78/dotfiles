#!/usr/bin/env bash

set -euo pipefail

output=$(
  niri msg -j outputs |
    jq -r '.[].name' |
    rofi -dmenu -p "󰍺 "
)

[[ -z "$output" ]] && exit 0

niri msg action move-window-to-monitor "$output"
