#!/usr/bin/env bash
nmcli device wifi rescan 2>/dev/null
sleep 1
saved=$(nmcli -g NAME connection show)

ssid=$(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list |
  awk -F: -v saved="$saved" '
    BEGIN { n=split(saved, a, "\n"); for(i=1;i<=n;i++) s[a[i]]=1 }
    NF>=4 && $4!="" && !seen[$4]++ {
      cur  = ($1 == "*") ? "▶" : " "
      mark = ($4 in s)   ? "*" : " "
      printf "%s%s %3s%%  %-10s %s\n", cur, mark, $2, $3, $4
    }' |
  sort -k2 -rn |
  fzf --layout=reverse --border --prompt="Wi-Fi > " \
    --header="▶ = connected, * = saved" |
  sed 's/^.\{2\} *[0-9]*% *[^ ]* *//')

[ -n "$ssid" ] && nmcli device wifi connect "$ssid" --ask
read -n1 -s -p "Press any key..."
