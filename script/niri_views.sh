#!/usr/bin/env bash

selection=$(
  niri msg --json windows |
    jq -r '.[] | "\(.workspace_id)\t\(.app_id)\t\(.title)\t\(.id)"' |
    sort -t $'\t' -k1,1n |
    sed 's/chromium-browser/ chromium/' |
    sed 's/com.mitchellh.ghostty/ ghostty/' |
    column -t -s $'\t' |
    rofi -dmenu -p " " -theme-str 'window{width: 40%; }'
)

id=$(awk '{print $NF}' <<<"$selection")

niri msg action focus-window --id "$id"
