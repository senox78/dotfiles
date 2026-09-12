#!/usr/bin/env python3

import os
import sys

# niri の spawn-sh / hyprland の exec_cmd は cwd がこのディレクトリにならないため、
# 隣の general_cmd_p.py を import できるよう自分の場所を sys.path に足す。
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import general_cmd_p

home = os.path.expanduser("~")
script = home + "/dotfiles/script/"
# kitty = home + "~/dotfiles/.config/kitty/"
slide_dev = home + "/Develop/linux_slide/"

cmds = {
    "󰸉 Turn on wallpaper cycle":    ["bash", script + "wallpaper_cycle_helper.sh", "enable"],
    "󰸉 Turn off wallpaper cycle":   ["bash", script + "wallpaper_cycle_helper.sh", "disable"],
    "󰸉 Status of wallpaper cycle":  ["bash", script + "wallpaper_cycle_helper.sh", "status"],
    "󰗽 Logout":                     ["hyprctl", "dispatch", "hl.dsp.exit()"],
    "󰜉 Reboot":                     ["reboot"],
    " Lock":                       ["hyprlock"],
    "󰔎 Toggle theme light-dark":    ["bash", script + "toggle_theme.sh"],
    "󰸉 Random wallpaper":           ["wlmstr", "next", "rnd"],
    "󱎐 Launch white in kitty":      ["kitty", "--config", home + "/dotfiles/.config/kitty/light.conf"],
}

general_cmd_p.pa(cmds)
