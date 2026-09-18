#!/usr/bin/env bash
# Meldt verwijzingen naar skills, agents of commands die niet meer bestaan.
# Kijkt alleen naar functionele oppervlakken: wat de plugin laadt of uitvoert.
# Lopende documentatie mag verdwenen namen noemen; dat breekt niets.
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BF="$ROOT/bf"
tmp="$(mktemp)"
trap 'rm -f "$tmp" "$tmp.ok" "$tmp.patronen"' EXIT

DIRS="skills agents commands workflows config manifests hooks scripts rules schemas src .claude-plugin"

doelen=""
for d in $DIRS; do
  [ -e "$ROOT/$d" ] && doelen="$doelen $ROOT/$d"
done

# shellcheck disable=SC2086
# Namen uit refs-ok.txt komen alleen in lopende tekst voor; die overslaan.
if [ -f "$BF/refs-ok.txt" ]; then
  grep -v '^#' "$BF/refs-ok.txt" | grep -v '^$' | sort > "$tmp.ok"
  comm -23 <(sort "$BF/verwijderd.txt") "$tmp.ok" > "$tmp.patronen"
else
  cp "$BF/verwijderd.txt" "$tmp.patronen"
fi

grep -rnoIF -f "$tmp.patronen" --exclude-dir=node_modules $doelen 2>/dev/null \
  | sed "s|^$ROOT/||" > "$tmp" || true

if [ ! -s "$tmp" ]; then
  echo "totaal nog verwezen: 0"
  exit 0
fi

awk -F: '{ naam=$NF; bestand=$1
    if (!(naam SUBSEP bestand in gezien)) { gezien[naam SUBSEP bestand]=1; per[naam]=per[naam] "\n    " bestand } }
  END { n=0; for (naam in per) { print "nog verwezen: " naam per[naam]; n++ } print "totaal nog verwezen: " n }' "$tmp"

aantal="$(awk -F: '{print $NF}' "$tmp" | sort -u | wc -l | tr -d ' ')"
[ "$aantal" -eq 0 ]
