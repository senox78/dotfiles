#!/usr/bin/env bash
# tmux の copy-pipe-and-cancel から呼ばれる。コピーした選択が stdin で渡ってくる。
#
# - ローカル (コンソールセッション) … Wayland クリップボードへ wl-copy
# - SSH 越し … リモートの Wayland には書き込まない。代わりに tmux が
#   set-clipboard on + terminal-features '*:osc52' で選択を OSC52 として
#   クライアント端末 (kitty / ghostty) へ自動転送するので、ここでは何もしない。
#   ここで wl-copy を叩くと「リモート側の」クリップボードを握るだけで無駄になる。
if [[ -z "${SSH_CONNECTION:-}" && -z "${SSH_TTY:-}" ]]; then
  exec wl-copy
fi
exit 0
