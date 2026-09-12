#!/usr/bin/env python3

import os
import sys

# cmd_p.py と同様、cwd に依存せず隣の general_cmd_p.py を import する。
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import general_cmd_p

# rofi を Esc で閉じれば general_cmd_p.pa が何も実行せず終了するため、
# Cancel の項目は不要（["exit"] は実行ファイルではないので落ちていた）。
#hyprctl dispatch 'hl.dsp.exit()'
cmds = {
    "󰗽 Logout": ["hyprctl", "dispatch", "hl.dsp.exit()"],
    "󰜉 Reboot": ["reboot"],
    " Lock":   ["hyprlock"],
}

general_cmd_p.pa(cmds)
