#!/usr/bin/env -S nix shell nixpkgs#pciutils --command bash
#
# nvme-pcie-info.sh
#   接続されている NVMe SSD の PCIe 世代 (Gen3/4/5) とリンク幅を表示する
#
#   使い方:
#     ./nvme-pcie-info.sh          通常表示
#     ./nvme-pcie-info.sh -v       lspci の詳細も表示
#
set -uo pipefail

VERBOSE=0
[[ "${1:-}" == "-v" || "${1:-}" == "--verbose" ]] && VERBOSE=1

# ---- 色設定（非TTYなら無効化） --------------------------------------------
if [[ -t 1 ]]; then
  BOLD=$'\e[1m'
  RED=$'\e[31m'
  GRN=$'\e[32m'
  YEL=$'\e[33m'
  CYA=$'\e[36m'
  RST=$'\e[0m'
else
  BOLD=''
  RED=''
  GRN=''
  YEL=''
  CYA=''
  RST=''
fi

# ---- GT/s → PCIe 世代 -------------------------------------------------------
gen_of() {
  case "${1%% *}" in
  2.5) echo "PCIe 1.0" ;;
  5 | 5.0) echo "PCIe 2.0" ;;
  8 | 8.0) echo "PCIe 3.0" ;;
  16 | 16.0) echo "PCIe 4.0" ;;
  32 | 32.0) echo "PCIe 5.0" ;;
  64 | 64.0) echo "PCIe 6.0" ;;
  *) echo "不明" ;;
  esac
}

read_attr() { # $1: ファイルパス（前後の空白をトリム）
  if [[ -r "$1" ]]; then
    sed -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' "$1" | head -n1
  else
    echo "N/A"
  fi
}

# ---- 事前チェック -----------------------------------------------------------
if [[ ! -d /sys/class/nvme ]] || ! compgen -G "/sys/class/nvme/nvme*" >/dev/null; then
  echo "${RED}NVMe デバイスが見つかりません。${RST}" >&2
  echo "SATA接続のM.2 SSD、または NVMe ドライバ未ロードの可能性があります。" >&2
  exit 1
fi

command -v lspci >/dev/null || echo "${YEL}※ lspci が未インストールです (apt install pciutils) — 一部情報を省略します${RST}" >&2

# ---- 本体 -------------------------------------------------------------------
for ctrl in /sys/class/nvme/nvme*; do
  name=$(basename "$ctrl")
  dev="$ctrl/device"

  model=$(read_attr "$ctrl/model")
  fw=$(read_attr "$ctrl/firmware_rev")
  serial=$(read_attr "$ctrl/serial")
  pciaddr=$(basename "$(readlink -f "$dev")" 2>/dev/null || echo "N/A")

  max_speed=$(read_attr "$dev/max_link_speed")
  cur_speed=$(read_attr "$dev/current_link_speed")
  max_width=$(read_attr "$dev/max_link_width")
  cur_width=$(read_attr "$dev/current_link_width")

  echo "${BOLD}=== /dev/$name ===${RST}"
  echo "  モデル       : ${CYA}${model}${RST}"
  echo "  シリアル     : $serial"
  echo "  FW           : $fw"
  echo "  PCIアドレス  : $pciaddr"
  echo

  echo "  ${BOLD}SSDの対応上限${RST} : $max_speed  ($(gen_of "$max_speed"))  x${max_width}"
  echo "  ${BOLD}現在のリンク  ${RST} : $cur_speed  ($(gen_of "$cur_speed"))  x${cur_width}"

  # ---- 判定 ----
  echo
  if [[ "$max_speed" == "N/A" || "$cur_speed" == "N/A" ]]; then
    echo "  ${YEL}▲ リンク情報を取得できませんでした（root権限が必要な場合があります）${RST}"
  elif [[ "$max_speed" == "$cur_speed" && "$max_width" == "$cur_width" ]]; then
    echo "  ${GRN}✓ フルスピードで動作中（$(gen_of "$cur_speed") x${cur_width}）${RST}"
  else
    echo "  ${RED}▲ 本来の性能が出ていません${RST}"
    [[ "$max_speed" != "$cur_speed" ]] &&
      echo "     速度: $(gen_of "$max_speed") 対応 → 実際は $(gen_of "$cur_speed")"
    [[ "$max_width" != "$cur_width" ]] &&
      echo "     レーン: x${max_width} 対応 → 実際は x${cur_width}"
    echo "     原因候補: マザーボード側スロットの世代 / BIOSのレーン分岐設定 /"
    echo "               変換アダプタ / 省電力によるリンクダウン(ASPM)"
  fi

  # ---- 温度（あれば） ----
  for hw in "$ctrl"/hwmon*/temp1_input; do
    if [[ -r "$hw" ]]; then
      awk -v t="$(cat "$hw")" 'BEGIN{printf "\n  温度         : %.1f °C\n", t/1000}'
      break
    fi
  done

  # ---- 詳細モード ----
  if [[ $VERBOSE -eq 1 && "$pciaddr" != "N/A" ]] && command -v lspci >/dev/null; then
    echo
    echo "  ${BOLD}--- lspci 詳細 ---${RST}"
    lspci -vv -s "$pciaddr" 2>/dev/null | grep -E 'LnkCap|LnkSta|Speed|Width' | sed 's/^/  /'
    if [[ $EUID -ne 0 ]]; then
      echo "  ${YEL}(sudo で実行するとより詳細が表示されます)${RST}"
    fi
  fi

  echo
done

# ---- ネームスペース一覧 ------------------------------------------------------
if command -v nvme >/dev/null; then
  echo "${BOLD}--- nvme list ---${RST}"
  nvme list 2>/dev/null || echo "${YEL}(sudo が必要です)${RST}"
fi
