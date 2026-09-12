#!/usr/bin/env python3

"""Small helper for showing command options in rofi and running the selection.

Usage:
    from general_cmd_p import pa

    pa({
        "Open terminal": ["alacritty"],
        "Lock screen": ["loginctl", "lock-session"],
    })

The dictionary key is the label shown in rofi.
The dictionary value is the command (argv list) executed by subprocess.run.
"""

import subprocess

def pa(cmds: dict[str,list[str]]):
    """Show command labels in rofi and execute the selected command."""
    keys_list = "\n".join(cmds.keys())
    cmd_res = subprocess.run(
        ["rofi", "-dmenu", "-i", "-p", "󰘳 "],
        input=keys_list, text=True, capture_output=True
    )

    if cmd_res.returncode != 0:
        exit(0)

    choice = cmds.get(cmd_res.stdout.strip())
    if choice is None:
        print("not chosen")
    else:
        subprocess.run(choice)
