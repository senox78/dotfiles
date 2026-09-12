#!/usr/bin/env bash
# 引数のファイルを Wayland の GUI クリップボードへ載せる。plugins/gui-copy.yazi から呼ぶ。
# 端末からブラウザへは D&D できないので、その代わりに貼り付けで渡すためのもの。
#
#   --auto    … 画像/テキスト 1 件なら中身を、それ以外・複数選択なら file:// URI を載せる
#   --content … 中身を強制(チャットやエディタへ Ctrl+V する用)
#   --uri     … file:// URI 一覧 = text/uri-list を強制
#                (Chromium 系のアップロード領域へ「ファイルとして」貼るのはこちら)
#
# 結果の一行サマリを stdout、エラーを stderr に出す。呼び出し側がそれを通知する。
set -euo pipefail

mode=auto
case "${1-}" in
	--auto | --content | --uri)
		mode=${1#--}
		shift
		;;
esac

(($# > 0)) || exit 0

mime_of() {
	# xdg-mime は `--` を受け付けない。yazi が渡すのは常に絶対パスなので問題ない。
	xdg-mime query filetype "$1" 2>/dev/null || echo application/octet-stream
}

# wl-copy は自分をバックグラウンドへ fork し、貼り付け要求が来るまで居座って
# データを提供し続ける。つまりこいつが死ぬと、offer だけ残って中身が取れない
# クリップボードになる(cliphist には残るのに貼れない、という状態)。
#   - setsid … yazi の子プロセスグループ / 端末から切り離す。付けないと yazi 側の
#               後始末や端末の SIGHUP で道連れになる
#   - >/dev/null 2>&1 … 呼び出し側は output() で待つので、fork した子に stdout を
#               握られると EOF が来ずに固まる
clip() {
	setsid wl-copy "$@" >/dev/null 2>&1
}

copy_content() {
	local f=$1 mime=$2
	case $mime in
		text/* | application/json | application/*+json | application/xml | application/*+xml)
			# --type を明示すると wl-copy が text/plain や UTF8_STRING の別名を
			# 提供しなくなり、ブラウザ側が拾えない。テキストは既定の型で載せる。
			clip <"$f"
			echo "${f##*/} の中身をコピー (text)"
			;;
		*)
			clip --type "$mime" <"$f"
			echo "${f##*/} の中身をコピー ($mime)"
			;;
	esac
}

copy_uris() {
	python3 -c '
import os, sys, urllib.parse
sys.stdout.write("".join(
    "file://" + urllib.parse.quote(os.path.abspath(p)) + "\r\n"  # RFC 2483: CRLF 区切り
    for p in sys.argv[1:]
))
' "$@" | clip --type text/uri-list
	if (($# == 1)); then
		echo "${1##*/} を file:// URI としてコピー"
	else
		echo "$# 件を file:// URI としてコピー"
	fi
}

case $mode in
	uri)
		copy_uris "$@"
		;;
	content)
		if (($# != 1)) || [ ! -f "$1" ]; then
			echo "中身をコピーできるのは通常ファイル 1 件のみ" >&2
			exit 1
		fi
		copy_content "$1" "$(mime_of "$1")"
		;;
	auto)
		if (($# == 1)) && [ -f "$1" ]; then
			mime=$(mime_of "$1")
			case $mime in
				image/* | text/* | application/json | application/*+json | application/xml | application/*+xml)
					copy_content "$1" "$mime"
					exit 0
					;;
			esac
		fi
		copy_uris "$@"
		;;
esac
