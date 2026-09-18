#!/usr/bin/env bash
# Verwijdert alles onder skills/, agents/ en commands/ dat niet in de
# bijbehorende houdlijst staat, plus elk pad uit bf/drop-files.txt.
# Draai dit opnieuw na elke samenvoeging met de bovenstroom.
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BF="$ROOT/bf"

removed=0

trim_dir() {
  dir="$ROOT/$1"
  keep="$BF/$2"
  suffix="$3"

  if [ ! -f "$keep" ]; then
    echo "houdlijst ontbreekt: $keep" >&2
    exit 1
  fi
  [ -d "$dir" ] || return 0

  for path in "$dir"/*; do
    [ -e "$path" ] || continue
    name="$(basename "$path")"
    if [ -n "$suffix" ]; then
      case "$name" in
        *"$suffix") name="${name%$suffix}" ;;
        *) continue ;;
      esac
    fi
    if ! grep -qxF "$name" "$keep"; then
      echo "verwijderd: $1/$name"
      rm -rf "$path"
      removed=$((removed + 1))
    fi
  done
}

trim_dir skills keep-skills.txt ""
trim_dir agents keep-agents.txt ".md"
trim_dir commands keep-commands.txt ".md"

if [ -f "$BF/drop-files.txt" ]; then
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    case "$rel" in \#*) continue ;; esac
    if [ -e "$ROOT/$rel" ]; then
      echo "verwijderd: $rel"
      rm -rf "${ROOT:?}/$rel"
      removed=$((removed + 1))
    fi
  done < "$BF/drop-files.txt"
fi

echo "klaar: $removed verwijderd"
