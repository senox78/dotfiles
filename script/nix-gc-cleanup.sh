#!/usr/bin/env bash
# Expire old Nix generations and reclaim the resulting unreachable store paths.
#
# Run without arguments to preview changes.  `--apply` is required before any
# profile generations or store paths are removed.

set -euo pipefail

readonly RETENTION_DAYS=7
readonly USER_STATE_DIR="${XDG_STATE_HOME:-"$HOME/.local/state"}/nix/profiles"
readonly USER_PROFILE="$USER_STATE_DIR/profile"
readonly HOME_MANAGER_PROFILE="$USER_STATE_DIR/home-manager"
readonly SYSTEM_PROFILE="/nix/var/nix/profiles/system"

usage() {
  cat <<'EOF'
Usage: nix-gc-cleanup.sh [--apply]

Preview the removal of NixOS, user Nix, and Home Manager profile generations
older than 7 days.  Pass --apply to perform the removal, run the system GC,
and optimise the Nix store.

The script intentionally does not remove .direnv directories or result links:
inspect and remove those project-by-project when they are no longer needed.
EOF
}

apply=false
case "${1:-}" in
  "") ;;
  --apply) apply=true ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

expire_profile() {
  local profile="$1"
  local label="$2"
  local -a command=(nix profile wipe-history --profile "$profile" --older-than "${RETENTION_DAYS}d")

  if [[ ! -L "$profile" ]]; then
    printf 'Skipping %s: %s does not exist.\n' "$label" "$profile"
    return
  fi

  printf '\n%s (%s)\n' "$label" "$profile"
  if [[ "$apply" == true ]]; then
    "${command[@]}"
  else
    "${command[@]}" --dry-run
  fi
}

expire_system_profile() {
  local -a command=(sudo nix profile wipe-history --profile "$SYSTEM_PROFILE" --older-than "${RETENTION_DAYS}d")

  printf '\nNixOS system profile (%s)\n' "$SYSTEM_PROFILE"
  if [[ "$apply" == true ]]; then
    "${command[@]}"
  else
    "${command[@]}" --dry-run
  fi
}

expire_system_profile
expire_profile "$USER_PROFILE" "User Nix profile"
expire_profile "$HOME_MANAGER_PROFILE" "Home Manager profile"

if [[ "$apply" == true ]]; then
  printf '\nCollecting unreachable store paths...\n'
  sudo nix-collect-garbage

  printf '\nOptimising the Nix store (deduplicating identical files)...\n'
  sudo nix-store --optimise
else
  cat <<'EOF'

This was a preview; no generations or store paths were removed.
Re-run with --apply to perform this cleanup.
EOF
fi
