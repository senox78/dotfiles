#!/usr/bin/env bash
# Install Fedora-owned desktop applications and everyday CLI tools.
# Project-specific toolchains belong in each project's Nix devShell.

set -euo pipefail

if [[ ! -r /etc/os-release ]]; then
  printf 'fedora-desktop-packages: /etc/os-release was not found\n' >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "fedora" ]]; then
  printf 'fedora-desktop-packages: Fedora is required (detected: %s)\n' "${ID:-unknown}" >&2
  exit 1
fi

readonly -a PACKAGES=(
  # Shell and everyday CLI
  bat
  brightnessctl
  btop
  chafa
  curl
  direnv
  difftastic
  eza
  fastfetch
  fd-find
  fish
  fzf
  gh
  git
  gnupg2
  htop
  jq
  lazygit
  man-db
  mediainfo
  neovim
  playerctl
  ripgrep
  tmux
  unzip
  vim
  wget
  yazi
  zip
  zsh

  # Desktop and Wayland integration
  emacs
  ffmpeg
  ffmpegthumbnailer
  firefox
  gnome-calendar
  gnome-text-editor
  gnome-tweaks
  inkscape
  kitty
  libreoffice
  loupe
  mpv
  nautilus
  niri
  pinta
  thunderbird
  vlc
  wl-clipboard

  # System services are managed by Fedora, not Home Manager.
  tailscale
)

sudo dnf install -y "${PACKAGES[@]}"
sudo systemctl enable --now tailscaled.service
