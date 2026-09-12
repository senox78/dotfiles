#!/usr/bin/env bash
set -uo pipefail

awk_prog='{m=$1=="performance"?"PRF":$1=="balanced"?"BAL":$1=="powersave"?"SAV":$1; print NF==2?m"/"$2:m}'

tlp-stat -s | grep -Ei 'Power profile|TLP Profile' | awk '{print $4}' |
  awk -F / "$awk_prog"
