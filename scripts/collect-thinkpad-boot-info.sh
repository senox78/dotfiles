#!/usr/bin/env bash
# Collect read-only diagnostics for the ThinkPad LUKS/swap boot failure.
# Usage:
#   sudo bash collect-thinkpad-boot-info.sh [OUTPUT_DIRECTORY] [DOTFILES_DIRECTORY]

set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
output_dir=${1:-$script_dir}
dotfiles_dir=${2:-}
timestamp=$(date '+%Y%m%d-%H%M%S')
output_file="$output_dir/thinkpad-boot-info-$timestamp.txt"

mkdir -p -- "$output_dir" || {
  echo "Cannot create output directory: $output_dir" >&2
  exit 1
}

exec > >(tee "$output_file") 2>&1

section() {
  printf '\n\n===== %s =====\n' "$1"
}

run() {
  printf '\n$'
  printf ' %q' "$@"
  printf '\n'
  "$@" || printf '[exit status: %s]\n' "$?"
}

grep_boot_refs() {
  local target=$1
  if [[ -e "$target" ]]; then
    grep -RInE \
      '44d1dc1d|022361ea|86adca68|0c8d6ba1|0432ea0c|0242-AE00|A963-2ADF|/dev/mapper/luks-|resume(_offset)?' \
      "$target" 2>/dev/null || true
  fi
}

section "collection metadata"
run date --iso-8601=seconds
run id
run pwd
printf 'script: %s\noutput: %s\n' "$0" "$output_file"
if (( EUID != 0 )); then
  printf '\nWARNING: Run this script as root; some journal and disk data may be missing.\n'
fi

section "system identity"
run uname -a
run hostnamectl
run cat /etc/os-release
run cat /proc/cmdline
run readlink -f /run/current-system
run readlink -f /nix/var/nix/profiles/system
run nixos-version

section "block devices and filesystems"
run lsblk -e 7 -o NAME,PATH,TYPE,SIZE,FSTYPE,FSVER,UUID,PARTUUID,LABEL,MOUNTPOINTS
run blkid
run findmnt --real --output TARGET,SOURCE,FSTYPE,OPTIONS
run swapon --show --output NAME,TYPE,SIZE,USED,PRIO,UUID
run cat /proc/swaps
run dmsetup ls --tree

section "LUKS mappings"
if command -v cryptsetup >/dev/null 2>&1; then
  while IFS= read -r mapper; do
    [[ -n "$mapper" ]] || continue
    run cryptsetup status "$mapper"
  done < <(ls /dev/mapper/luks-* 2>/dev/null || true)
fi

section "generated hardware configuration"
if command -v nixos-generate-config >/dev/null 2>&1; then
  run nixos-generate-config --show-hardware-config
fi

section "fstab and crypttab"
run cat /etc/fstab
if [[ -e /etc/crypttab ]]; then
  run cat /etc/crypttab
else
  printf '/etc/crypttab does not exist\n'
fi

section "boot loader"
if command -v bootctl >/dev/null 2>&1; then
  run bootctl status --no-pager
  run bootctl list --no-pager
fi
run find /boot/loader -maxdepth 3 -type f -printf '%p\n'
for entry in /boot/loader/entries/*.conf; do
  [[ -e "$entry" ]] || continue
  run cat "$entry"
done

section "NixOS generations"
run nix-env --profile /nix/var/nix/profiles/system --list-generations
for generation in /nix/var/nix/profiles/system*-link; do
  [[ -e "$generation" ]] || continue
  printf '\n--- %s -> %s ---\n' "$generation" "$(readlink -f "$generation")"
  ls -la "$generation" 2>&1 || true
  for file in kernel-params boot.json etc/fstab etc/crypttab; do
    if [[ -f "$generation/$file" ]]; then
      printf '\n[%s/%s]\n' "$generation" "$file"
      cat "$generation/$file" 2>&1 || true
    fi
  done
done

section "systemd boot dependencies"
run systemctl --failed --no-pager --full
run systemctl list-units --all --no-pager --full 'dev-mapper-*.device' '*.swap' 'systemd-cryptsetup@*.service'
run systemctl list-dependencies --all --no-pager swap.target
run systemctl list-dependencies --all --no-pager local-fs.target
run systemctl show swap.target -p Wants -p Requires -p After -p Before
while read -r unit _; do
  [[ -n "$unit" ]] || continue
  printf '\n--- %s ---\n' "$unit"
  systemctl show "$unit" \
    -p Id -p Names -p Description -p LoadState -p ActiveState -p SubState \
    -p FragmentPath -p SourcePath -p Wants -p Requires -p After -p Before 2>&1 || true
  systemctl cat --no-pager "$unit" 2>&1 || true
done < <(systemctl list-units --all --plain --no-legend '*.swap' 'systemd-cryptsetup@*.service' 2>/dev/null || true)

section "references in live configuration"
for target in \
  /etc/fstab \
  /etc/crypttab \
  /etc/nixos \
  /etc/systemd \
  /run/systemd/generator \
  /run/systemd/generator.early \
  /run/systemd/generator.late \
  /boot/loader/entries; do
  printf '\n--- %s ---\n' "$target"
  grep_boot_refs "$target"
done

section "dotfiles configuration"
if [[ -z "$dotfiles_dir" ]]; then
  for candidate in /home/*/dotfiles /root/dotfiles; do
    if [[ -f "$candidate/flake.nix" ]]; then
      dotfiles_dir=$candidate
      break
    fi
  done
fi
if [[ -n "$dotfiles_dir" && -d "$dotfiles_dir" ]]; then
  printf 'dotfiles directory: %s\n' "$dotfiles_dir"
  run git -C "$dotfiles_dir" status --short
  run git -C "$dotfiles_dir" rev-parse HEAD
  for file in \
    "$dotfiles_dir/flake.nix" \
    "$dotfiles_dir/hosts/thinkpad/configuration.nix" \
    "$dotfiles_dir/hosts/thinkpad/hardware-configuration.nix"; do
    if [[ -f "$file" ]]; then
      printf '\n--- %s ---\n' "$file"
      cat "$file"
    fi
  done
else
  printf 'Dotfiles repository was not found. Pass its path as the second argument.\n'
fi

section "initrd inventory"
if command -v lsinitrd >/dev/null 2>&1 && [[ -e /run/current-system/initrd ]]; then
  lsinitrd /run/current-system/initrd 2>&1 \
    | grep -Ei 'crypt|luks|swap|resume|fstab|systemd.*device' \
    || true
else
  printf 'lsinitrd is unavailable or /run/current-system/initrd does not exist.\n'
fi

section "boot journals"
run journalctl --list-boots --no-pager
for boot in 0 -1 -2; do
  printf '\n--- boot %s: relevant messages ---\n' "$boot"
  journalctl -b "$boot" --no-pager -o short-monotonic 2>/dev/null \
    | grep -Ei 'luks|crypt|mapper|swap|resume|timed out|dependency failed|amdgpu|dmcub|dmub' \
    | tail -n 1500 \
    || true
done

section "kernel messages"
dmesg --ctime 2>/dev/null \
  | grep -Ei 'luks|crypt|mapper|swap|resume|timed out|amdgpu|dmcub|dmub|nvme' \
  | tail -n 1500 \
  || true

section "finished"
printf 'Diagnostic report written to:\n%s\n' "$output_file"
