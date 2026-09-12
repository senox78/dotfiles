#!/usr/bin/env bash

# --- 1. 設定: 内蔵オーディオの定義 ---
# あなたの環境の "Ryzen HD Audio Controller" のカードIDを取得
# (pactl list cards の Card #44 に相当するものを動的に取得)
CARD_ID=$(wpctl status | grep "Ryzen HD Audio Controller" | head -n1 | sed 's/[^0-9]*\([0-9]\+\).*/\1/')

# プロファイル名 (pactl の出力に基づき正確に記述)
# ※ wpctl では profile 番号または名前で指定しますが、名前で指定するのが確実です
PROF_HP="HiFi (Headphones, Mic1, Mic2)"
PROF_SPK="HiFi (Mic1, Mic2, Speaker)"

# メニューの表示名
NAME_HP="Built-in Headphones"
NAME_SPK="Built-in Speakers"

# --- 2. 外部デバイス（Bluetooth/USBなど）のリスト取得 ---
# wpctl status の Sinks セクションから内蔵以外を取得
OTHER_SINKS=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -v "Ryzen HD Audio Controller" | grep -E "^\s+\*" | sed 's/^\s*\*//' | awk '{print $1 ": " $2}')
# もし何も選択されていない(星印がない)デバイスも含める場合はこちら
OTHER_SINKS_ALL=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -E "^\s*[0-9]+\." | grep -v "Ryzen HD Audio Controller" | sed 's/^\s*//' | sed 's/\.//')

# --- 3. メニューの構築 ---
MENU=$(echo -e "$NAME_HP\n$NAME_SPK\n$OTHER_SINKS_ALL")

# --- 4. Wofi表示 ---
SELECTED=$(echo -e "$MENU" | wofi --dmenu --cache-file /dev/null --prompt "Audio Output" --width 400 --height 250)

if [ -z "$SELECTED" ]; then
    exit 0
fi

# --- 5. 切り替え処理 ---
if [[ "$SELECTED" == "$NAME_HP" ]]; then
    # 内蔵ヘッドフォンへ
    wpctl set-profile "$CARD_ID" "$PROF_HP"
    notify-send "Audio" "Switched to Headphones"

elif [[ "$SELECTED" == "$NAME_SPK" ]]; then
    # 内蔵スピーカーへ
    wpctl set-profile "$CARD_ID" "$PROF_SPK"
    notify-send "Audio" "Switched to Speakers"

else
    # その他のデバイス（IDを取得してデフォルトに設定）
    SINK_ID=$(echo "$SELECTED" | awk '{print $1}' | tr -d ':')
    if [[ -n "$SINK_ID" ]]; then
        wpctl set-default "$SINK_ID"
        notify-send "Audio" "Switched to External Device (ID: $SINK_ID)"
    fi
fi
