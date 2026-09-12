#!/usr/bin/env bash
# Bootstrap this dotfiles repository on Fedora as standalone Home Manager.

set -euo pipefail

readonly CURRENT_USER="$(id -un)"
readonly EXPECTED_ARCH="x86_64"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly EXPECTED_REPO_DIR="$HOME/dotfiles"

fail() {
  printf 'fedora-home-manager-bootstrap: %s\n' "$*" >&2
  exit 1
}

if [[ "$(id -u)" -eq 0 ]]; then
  fail "run this script as a regular user, not as root"
fi

if [[ ! -r /etc/os-release ]]; then
  fail "/etc/os-release was not found"
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "fedora" ]]; then
  fail "this script supports Fedora only (detected: ${ID:-unknown})"
fi

if [[ "$(uname -m)" != "$EXPECTED_ARCH" ]]; then
  fail "the current flake supports $EXPECTED_ARCH-linux only"
fi

if [[ "$REPO_DIR" != "$EXPECTED_REPO_DIR" ]]; then
  fail "place this repository at $EXPECTED_REPO_DIR (current: $REPO_DIR)"
fi

printf 'Installing the Fedora-owned system layer...\n'
sudo -v
sudo dnf install -y curl fish git niri

readonly FISH_PATH="$(command -v fish)"
readonly LOGIN_SHELL="$(getent passwd "$CURRENT_USER" | cut -d: -f7)"
if [[ "$LOGIN_SHELL" != "$FISH_PATH" ]]; then
  printf 'Setting %s as the login shell...\n' "$FISH_PATH"
  sudo usermod --shell "$FISH_PATH" "$CURRENT_USER"
fi

if ! command -v nix >/dev/null 2>&1; then
  printf 'Installing Determinate Nix (multi-user, SELinux-aware)...\n'
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
fi

# Make a just-installed multi-user Nix available to this running Bash process.
if ! command -v nix >/dev/null 2>&1 \
  && [[ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  # shellcheck disable=SC1091
  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

command -v nix >/dev/null 2>&1 \
  || fail "Nix was installed but is not available; log out, log in, and rerun the script"

# This also supports an existing upstream Nix installation whose global config
# has not enabled flakes yet.  Home Manager will later link .config/nix/nix.conf.
if [[ -n "${NIX_CONFIG:-}" ]]; then
  export NIX_CONFIG="${NIX_CONFIG}"$'\n''experimental-features = nix-command flakes'
else
  export NIX_CONFIG='experimental-features = nix-command flakes'
fi

readonly FLAKE_OUTPUT="$(nix eval --raw "$REPO_DIR#lib.userName")"
if [[ "$CURRENT_USER" != "$FLAKE_OUTPUT" ]]; then
  fail "flake.nix configures user $FLAKE_OUTPUT, but the current user is $CURRENT_USER"
fi

printf 'Building the standalone Home Manager configuration...\n'
nix build \
  "$REPO_DIR#homeConfigurations.${FLAKE_OUTPUT}.activationPackage" \
  --no-link

# A unique extension makes the first activation safe even when Fedora has
# already created paths such as ~/.config/fish.  Later runs normally have no
# unmanaged collisions and can use `home-manager switch` directly.
readonly BACKUP_EXTENSION="pre-home-manager-$(date -u +%Y%m%dT%H%M%SZ)"

printf 'Activating Home Manager (collision backup: .%s)...\n' "$BACKUP_EXTENSION"
nix run home-manager/master -- \
  switch \
  -b "$BACKUP_EXTENSION" \
  --flake "$REPO_DIR#$FLAKE_OUTPUT"

printf '\nBootstrap completed. Log out and back in to refresh the fish and graphical sessions.\n'
printf 'Future updates: home-manager switch --flake %s#%s\n' "$REPO_DIR" "$FLAKE_OUTPUT"
