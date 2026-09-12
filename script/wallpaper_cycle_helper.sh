#!/usr/bin/env bash

disable() {
  systemctl --user stop cycle_wallpaper.timer &&
    notify-send "wallpaper cycle disabled." -a "wch"
}

enable() {
  systemctl --user start cycle_wallpaper.timer &&
    notify-send "wallpaper cycle enabled." -a "wch"
}

case "$1" in
disable)
  disable
  ;;
enable)
  enable
  ;;
toggle)
  if systemctl --user is-active --quiet cycle_wallpaper.timer; then
    disable
  else
    enable
  fi
  ;;
status)
  if systemctl --user is-active --quiet cycle_wallpaper.timer; then

    res=$(
      wlmstr status json |
        jq -r '
      ["status:", "cycle is active"],
      ["current:", (.paper_path | split("/") | last)],
      ["next:", (.next_path | split("/") | last)]
      | @tsv
    ' |
        column -t -s $'\t'
    )
  else
    res="cycle is not active"
  fi

  notify-send "$res"
  ;;
*)
  echo "unkown. support only enable, disable, status or toggle"
  exit 1
  ;;
esac
