#!/usr/bin/env bash

# mpris.sh <status|title|artist|progress|art>

set -u

XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="$XDG_CACHE_HOME/hyprlock"
mkdir -p "$CACHE_DIR"

_player() {
    playerctl --list-all 2>/dev/null | head -1
}

_is_active() {
    local player="$1" status
    status="$(playerctl --player="$player" status 2>/dev/null)"
    [[ "$status" == "Playing" || "$status" == "Paused" ]]
}

mpris_status() {
    local player status icon
    player="$(_player)"
    [[ -z "$player" ]] && return
    status="$(playerctl --player="$player" status 2>/dev/null)"
    case "$status" in
        Playing)
            case "$player" in
                *spotify*)          icon="󰓇" ;;
                *mpd*|*mopidy*)     icon="󰎆" ;;
                *firefox*|*chrom*)  icon="󰈹" ;;
                *)                  icon="󰝚" ;;
            esac
            echo "$icon  Now Playing"
            ;;
        Paused)
            echo "󰏤  Paused"
            ;;
    esac
}

mpris_title() {
    local player title
    player="$(_player)"
    [[ -z "$player" ]] && return
    _is_active "$player" || return
    title="$(playerctl --player="$player" metadata title 2>/dev/null)"
    [[ -z "$title" ]] && return
    if (( ${#title} > 28 )); then
        echo "${title:0:26}…"
    else
        echo "$title"
    fi
}

mpris_artist() {
    local player artist
    player="$(_player)"
    [[ -z "$player" ]] && return
    _is_active "$player" || return
    artist="$(playerctl --player="$player" metadata artist 2>/dev/null)"
    [[ -z "$artist" ]] && return
    if (( ${#artist} > 32 )); then
        echo "${artist:0:30}…"
    else
        echo "$artist"
    fi
}

mpris_progress() {
    local player pos length len_sec pos_min pos_sec len_min len_sec_r filled bar i
    player="$(_player)"
    [[ -z "$player" ]] && return
    _is_active "$player" || return
    pos="$(playerctl --player="$player" position 2>/dev/null | cut -d. -f1)"
    length="$(playerctl --player="$player" metadata mpris:length 2>/dev/null)"
    [[ -z "$pos" || -z "$length" ]] && return
    len_sec=$(( length / 1000000 ))
    (( len_sec == 0 )) && return
    pos_min=$(( pos / 60 ))
    pos_sec=$(( pos % 60 ))
    len_min=$(( len_sec / 60 ))
    len_sec_r=$(( len_sec % 60 ))
    filled=$(( pos * 16 / len_sec ))
    (( filled > 16 )) && filled=16
    bar=""
    for (( i = 1; i <= filled; i++ )); do bar="${bar}━"; done
    for (( i = filled + 1; i <= 16; i++ )); do bar="${bar}─"; done
    printf "%d:%02d  %s  %d:%02d\n" "$pos_min" "$pos_sec" "$bar" "$len_min" "$len_sec_r"
}

mpris_art() {
    local player url trackid cached
    player="$(_player)"
    [[ -z "$player" ]] && return
    _is_active "$player" || return
    url="$(playerctl --player="$player" metadata mpris:artUrl 2>/dev/null)"
    [[ -z "$url" ]] && return
    if [[ "$url" == file://* ]]; then
        echo "${url#file://}"
    else
        trackid="$(playerctl --player="$player" metadata mpris:trackid 2>/dev/null | tr -dc 'a-zA-Z0-9' | tail -c 40)"
        cached="${CACHE_DIR}/art_${trackid}.jpg"
        if [[ ! -f "$cached" ]]; then
            rm -f "$CACHE_DIR"/art_*.jpg 2>/dev/null
            curl -sL "$url" -o "$cached" 2>/dev/null
        fi
        [[ -f "$cached" ]] && echo "$cached"
    fi
}

case "${1:-}" in
    status)   mpris_status   ;;
    title)    mpris_title    ;;
    artist)   mpris_artist   ;;
    progress) mpris_progress ;;
    art)      mpris_art      ;;
    *)
        echo "Usage: $0 <status|title|artist|progress|art>" >&2
        exit 1
        ;;
esac
