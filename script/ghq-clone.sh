#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  exec 3<&0
else
  exec 3<"$1"
fi

while IFS= read -r repo <&3 || [ -n "$repo" ]; do
  [ -z "$repo" ] && continue
  repo=${repo#https://github.com/}
  repo=${repo#http://github.com/}
  repo=${repo#git@github.com:}
  repo=${repo%.git}
  case "$repo" in
    github.com/*) repo=${repo#github.com/} ;;
    *)  printf 'skip: %s\n' "$repo" >&2; continue;;
  esac
  printf 'ghq get %s\n' "git@github.com:$repo"
  if ! ghq get "git@github.com:$repo"; then
    printf 'FAILED: %s\n' "$repo" >&2
  fi
done
exec 3<&-
