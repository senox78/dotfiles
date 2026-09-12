#!/usr/bin/env bash
set -uo pipefail

CURRENT=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)

if [[ "$CURRENT" == *dark* ]]; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
  notify-send -i weather-clear "Theme" "Switched to Light Mode"
else
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  notify-send -i weather-clear-night "Theme" "Switched to Dark Mode"
fi
