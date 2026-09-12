#!/usr/bin/env bash
# Streams the focused column's width ratio (tile width / output width) to waybar.
# Emits one JSON line per niri event so waybar updates live (no polling).
set -euo pipefail

print_state() {
  local win out tile_w logical_w pct

  win=$(niri msg --json focused-window)
  if [[ -z "$win" || "$win" == "null" ]]; then
    echo '{"text": ""}'
    return
  fi

  tile_w=$(jq '.layout.tile_size[0] // empty' <<<"$win")
  if [[ -z "$tile_w" ]]; then
    echo '{"text": ""}'
    return
  fi

  out=$(niri msg --json focused-output)
  logical_w=$(jq '.logical.width // empty' <<<"$out")
  if [[ -z "$logical_w" ]]; then
    echo '{"text": ""}'
    return
  fi

  # nearest simple fraction (smallest denominator) for the width ratio
  jq -nc --argjson t "$tile_w" --argjson w "$logical_w" '
    ($t / $w) as $r
    | (reduce range(1; 9) as $d ({err: 2, n: 1, d: 1};
        ((($r * $d) | round) as $n
         | (($r - ($n / $d)) | fabs) as $e
         | if $e < (.err - 1e-9) then {err: $e, n: $n, d: $d} else . end))) as $f
    | "\($f.n)/\($f.d)" as $frac
    | {text: ("󰉹 " + $frac), tooltip: ("column width: " + $frac + " of screen")}'
}

print_state

niri msg --json event-stream | while read -r _; do
  print_state
done
