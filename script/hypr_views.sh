#!/usr/bin/env bash

selection=$(
  hyprctl clients -j |
    jq -r '.[] | "\(.workspace.id)\t\(.class)\t\(.title)\t\(.address)"' |
    sort -t $'\t' -k1,1n |
    sed 's/chromium-browser/ chromium/' |
    sed 's/com.mitchellh.ghostty/ ghostty/' |
    column -t -s $'\t' |
    rofi -dmenu -p " " -theme-str 'window{width: 40%; }'
)

address=$(awk '{print $NF}' <<<"$selection")

hyprctl dispatch focuswindow "address:$address"
