#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Uliboooo
#
# Interactive wallpaper picker for a window manager.
#
# Usage: wallpaper_selector.sh <dir>
#
# Presents all images in <dir> as a searchable list, lets the user pick
# one, and applies it as the current wallpaper. Ties the choice back to
# the underlying file by keeping the list and the file lookup in sync.

dir=$1

choice=$(
  fd . "$dir" |
    while read -r img; do
      printf '%s\0icon\x1f%s\n' \
        "${img##*/}" \
        "$img"
    done |
    rofi \
      -dmenu \
      -show-icons \
      -format i \
      -p " " \
      -theme-str '
        window {
          height: 90%;
        }
        listview {
          dynamic: true;
          lines: 20;
        }'
)

[ -n "$choice" ] &&
  fd . "$dir" |
  sed -n "$((choice + 1))p" |
    xargs -r -I{} awww img "{}" --transition-type center --transition-duration 0.5
