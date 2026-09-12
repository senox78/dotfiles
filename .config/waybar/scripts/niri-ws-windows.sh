#!/usr/bin/env bash
# Streams the current workspace's window list to a waybar custom module.
# Emits one JSON line per niri event so waybar updates live (no polling).
set -euo pipefail

declare -A icons=(
  [ghostty]="󰊠"
  ["com.mitchellh.ghostty"]="󰊠"
  ["com.obsproject.Studio"]="󰻃"
  [google-chrome]=""
  [Google-chrome]=""
  [firefox]=""
  [kitty]="󰄛"
  [emacs]=""
  [org.gnome.Nautilus]=""
  [chromium-browser]=""
  [discord]=""
  [obsidian]="󰠮"
  [spotify]=""
  [vlc]="󰕼"
  [mpv]="󰎁"
  ["com.github.rafostar.Clapper"]=""
  ["org.pwmt.zathura"]="󰈦"
  [sioyek]="󰈦"
  ["org.gnome.Papers"]="󰈦"
  ["org.inkscape.Inkscape"]="󰕝"
  ["org.kde.kdenlive"]=""
  ["org.gnome.Loupe"]="󰋩"
  ["org.gnome.Snapshot"]="󰄀"
  ["com.github.PintaProject.Pinta"]="󰏘"
  ["virt-manager"]="󰒋"
  ["org.gnome.Settings"]=""
  ["org.gnome.Calculator"]=""
  ["org.gnome.Calendar"]=""
  ["org.gnome.Maps"]=""
  ["org.gnome.Music"]=""
  ["org.gnome.Decibels"]=""
  ["org.gnome.Epiphany"]=""
  ["org.gnome.SimpleScan"]=""
  ["org.gnome.TextEditor"]="󰈙"
  ["libreoffice-writer"]=""
  ["libreoffice-calc"]=""
  ["libreoffice-impress"]=""
  [gvim]=""
  [xterm]=""
  [zen]="◎"
  [neovide]=""
)

declare -A names=(
  [ghostty]="Ghostty"
  ["com.mitchellh.ghostty"]="Ghostty"
  ["com.obsproject.Studio"]="OBS Studio"
  [google-chrome]="Chrome"
  [Google-chrome]="Chrome"
  [firefox]="Firefox"
  [kitty]="Kitty"
  [emacs]="Emacs"
  [org.gnome.Nautilus]="Nautilus"
  [chromium-browser]="Chromium"
  [discord]="Discord"
  [obsidian]="Obsidian"
  [spotify]="Spotify"
  [vlc]="VLC"
  [mpv]="mpv"
  ["com.github.rafostar.Clapper"]="Clapper"
  ["org.pwmt.zathura"]="Zathura"
  [sioyek]="Sioyek"
  ["org.gnome.Papers"]="Papers"
  ["org.inkscape.Inkscape"]="Inkscape"
  ["org.kde.kdenlive"]="Kdenlive"
  ["org.gnome.Loupe"]="Loupe"
  ["org.gnome.Snapshot"]="Snapshot"
  ["com.github.PintaProject.Pinta"]="Pinta"
  ["virt-manager"]="VMs"
  ["org.gnome.Settings"]="Settings"
  ["org.gnome.Calculator"]="Calc"
  ["org.gnome.Calendar"]="Calendar"
  ["org.gnome.Maps"]="Maps"
  ["org.gnome.Music"]="Music"
  ["org.gnome.Decibels"]="Decibels"
  ["org.gnome.Epiphany"]="Epiphany"
  ["org.gnome.SimpleScan"]="Scan"
  ["org.gnome.TextEditor"]="TextEditor"
  ["libreoffice-writer"]="Writer"
  ["libreoffice-calc"]="Calc"
  ["libreoffice-impress"]="Impress"
  [gvim]="GVim"
  [xterm]="XTerm"
  [zen]="zen"
  [neovide]="neovide"
)

xml_escape() {
  sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

print_state() {
  local focused_ws windows count text tooltip icon app_id title focused app_name

  focused_ws=$(niri msg --json workspaces | jq '[.[] | select(.is_focused)][0].id // empty')
  if [[ -z "$focused_ws" ]]; then
    echo '{"text": ""}'
    return
  fi

  windows=$(niri msg --json windows | jq --argjson ws "$focused_ws" \
    '[.[] | select(.workspace_id == $ws)] | sort_by(.layout.pos_in_scrolling_layout[0], .layout.pos_in_scrolling_layout[1])')

  count=$(jq 'length' <<<"$windows")
  if [[ "$count" -eq 0 ]]; then
    echo '{"text": ""}'
    return
  fi

  text=""
  tooltip=""
  while IFS=$'\t' read -r app_id title focused; do
    icon="${icons[$app_id]:-$app_id}"
    if [[ "$focused" == "true" ]]; then
      app_name="${names[$app_id]:-$app_id}"
      text+="${icon} ${app_name} | "
    else
      text+="${icon} | "
    fi
    tooltip+="$(xml_escape <<<"$title")"$'\n'
  done < <(jq -r '.[] | [.app_id, .title, .is_focused] | @tsv' <<<"$windows")

  text="${text% | }"
  tooltip="${tooltip%$'\n'}"

  jq -nc --arg text "$text" --arg tooltip "$tooltip" '{text: $text, tooltip: $tooltip}'
}

print_state

niri msg --json event-stream | while read -r _; do
  print_state
done
