# Uncoated Paper Design Manual

このメモは、Waybar / Hyprland / niri / SwayNC を「静的で落ち着いた、非塗工紙の UI」に寄せるためのデザイン規約です。

以前の neon pipeline 風の見た目から、発光・透過・角丸・強い影を抜き、紙面に印刷された罫線と文字だけで状態を読める方向に揃えます。

## Design Principles

- 紙面は透けない。背景、通知、バー、カードは不透明にする。
- 角丸は使わない。`border-radius: 0` / `rounding = 0` / `geometry-corner-radius 0` を基本にする。
- 影は使わない。紙の階層は影ではなく、余白と細い罫線で分ける。
- blur は使わない。アルバムアートや terminal 背景もぼかさない。
- 黒ベタは使わない。濃い色は文字色の `ink` だけに留める。
- 警告色は本当に警告の時だけ使う。active / focus は柔らかい rose を使う。
- 派手な状態変化は避ける。hover / active は背景を強く塗らず、文字色か細い線で示す。

## Palette

| Role | Color | Use |
| :--- | :--- | :--- |
| paper | `#f1eee5` | bar / control center の基本紙面 |
| paper-light | `#fbf9f2` | notification / tooltip / inner surface |
| ink | `#2d302b` | main text |
| ink-muted | `#77766d` | secondary text / inactive text |
| rule | `#b7b0a2` | main border |
| rule-soft | `#d0c9bb` | module separator / low-priority border |
| rose | `#d38ca0` | active workspace / focus border / selected state |
| rose-wash | `#ead2d9` | hover / soft selected background |
| warning | `#a84435` | critical battery / temperature / urgent |

透明度付きカラーは避けます。Hyprland / niri の border も `rgba(...)` ではなく `rgb(...)` または `#rrggbb` を使います。

## Waybar

対象ファイル:

- `.config/waybar/style.css`
- `.config/waybar/config.hypr.jsonc`
- `.config/waybar/config.niri.jsonc`
- `.config/waybar/scripts/hypr-ws-windows.sh`
- `.config/waybar/scripts/niri-ws-windows.sh`

Waybar は「細い紙の帯」として扱います。

- `window#waybar` は `paper` の不透明背景にする。
- 下端だけ `rule` の 1px border を引く。
- 各 module は背景を透明にし、左罫線 `rule-soft` で区切る。
- workspace button は border / shadow / background image / radius を全部消す。
- active workspace は `rose` の文字色と太字だけで示す。
- urgent は `warning` を使う。
- calendar の month / today は `rose` に合わせる。
- window list script は Powerline 記号や Pango の背景塗りを使わず、`icon app | icon | ...` の素直な文字列にする。

Waybar で避けるもの:

- Powerline の `` / `` を使った疑似的な丸い capsule
- module ごとの色分け
- hover 時の濃い塗り
- 残った button border や GTK の shadow

## Hyprland

対象ファイル:

- `.config/hypr/config/options.lua`

Hyprland は Waybar と同じ「紙面上の罫線」として window border を扱います。

推奨値:

```lua
general = {
  col = {
    active_border = "rgb(d38ca0)",
    inactive_border = "rgb(989286)",
  },
}

decoration = {
  rounding = 0,
  active_opacity = 1.0,
  inactive_opacity = 1.0,
  fullscreen_opacity = 1.0,
  blur = {
    enabled = false,
  },
  shadow = {
    enabled = false,
  },
}
```

注意:

- active border に赤や橙寄りの色を使うと警告に見えるので避ける。
- inactive border は透明にしない。紙の上で「薄い罫線」として見える不透明色にする。
- opacity で奥行きを作らない。紙の UI では透け方が不自然になる。

## niri

対象ファイル:

- `.config/niri/config.kdl`

niri も Hyprland と同じ visual rule に合わせます。

推奨値:

```kdl
layout {
    border {
        on
        width 4
        active-color "#d38ca0"
        inactive-color "#989286"
    }

    shadow {
        off
    }
}

window-rule {
    geometry-corner-radius 0
    clip-to-geometry true
}
```

注意:

- global blur block は置かない。
- terminal や notification 用の `background-effect { blur true; }` は使わない。
- focus-ring と border の両方を強く出すと二重に見えるので、基本は border に寄せる。

## SwayNC

対象ファイル:

- `.config/swaync/colors.css`
- `.config/swaync/style.css`

SwayNC は黒い media card や album-art blur が入りやすいので、標準 CSS の変数も上書きします。

必須の方針:

- `--noti-bg-alpha: 1`
- `--notification-shadow: none`
- `--mpris-album-art-overlay: #fbf9f2`
- `--mpris-album-art-shadow: none`
- `.notification`, `.control-center`, `.widget-mpris-player` はすべて `border-radius: 0` / `box-shadow: none`
- `.mpris-background` は `filter: none`
- `.mpris-overlay` は不透明な `paper-light`

MPRIS は特に黒い overlay が残りやすいので、通知と同じ紙面・罫線に揃えます。アルバムアートを装飾背景として使うより、情報カードとして読めることを優先します。

## ログイン画面 (対象外)

ログイン画面は **Paper Design の対象外**です。2026-08-04 に greeter を greetd + ReGreet
から GDM に戻したため、見た目は GNOME の Adwaita 固定になります。GDM の greeter は
gnome-shell そのもので、テーマを差し替える口が `extraCss` のような形では無く、
ここで規約を持っても実装できません。

かつては ReGreet(cage 上の GTK4)に `.config/greetd/regreet.css` で paper 配色を
当てていました。その設計と、tuigreet では 16 色に落ちて `paper` / `ink` / `rose` を
再現できなかった経緯は [../chglog/login.md](../chglog/login.md) に残してあります。

## Checklist

新しい UI 要素を追加する時は、次を確認します。

- `border-radius` が 0 になっている。
- `box-shadow`, `text-shadow`, `filter: blur(...)` が残っていない。
- 背景が透明や半透明ではなく、必要な面は不透明になっている。
- active / selected は `rose`、warning / critical は `warning` に分かれている。
- 黒ベタ背景を使っていない。
- state は色数を増やさず、文字色・太字・細い罫線で示している。
- Waybar / Hyprland / niri / SwayNC の focus 色が同じ `rose` 系に揃っている。

