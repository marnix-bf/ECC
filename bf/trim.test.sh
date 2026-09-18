#!/usr/bin/env bash
# Test voor bf/trim.sh: bouwt een neptree en controleert wat er overblijft.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

mkdir -p "$TMP/skills/houden" "$TMP/skills/weg" "$TMP/agents" "$TMP/commands" "$TMP/bf" "$TMP/scripts/hooks"
echo x > "$TMP/skills/houden/SKILL.md"
echo x > "$TMP/skills/weg/SKILL.md"
echo x > "$TMP/agents/houden.md"
echo x > "$TMP/agents/weg.md"
echo x > "$TMP/commands/houden.md"
echo x > "$TMP/commands/weg.md"
echo x > "$TMP/scripts/hooks/insaits-security-monitor.py"

printf 'houden\n' > "$TMP/bf/keep-skills.txt"
printf 'houden\n' > "$TMP/bf/keep-agents.txt"
printf 'houden\n' > "$TMP/bf/keep-commands.txt"
printf 'scripts/hooks/insaits-security-monitor.py\n' > "$TMP/bf/drop-files.txt"

output="$(bash "$HERE/trim.sh" "$TMP")"

[ -d "$TMP/skills/houden" ] || fail "skills/houden had moeten blijven"
[ ! -d "$TMP/skills/weg" ] || fail "skills/weg had weg gemoeten"
[ -f "$TMP/agents/houden.md" ] || fail "agents/houden.md had moeten blijven"
[ ! -f "$TMP/agents/weg.md" ] || fail "agents/weg.md had weg gemoeten"
[ -f "$TMP/commands/houden.md" ] || fail "commands/houden.md had moeten blijven"
[ ! -f "$TMP/commands/weg.md" ] || fail "commands/weg.md had weg gemoeten"
[ ! -f "$TMP/scripts/hooks/insaits-security-monitor.py" ] || fail "los bestand had weg gemoeten"

case "$output" in
  *"skills/weg"*) ;;
  *) fail "verwijdering van skills/weg werd niet gemeld" ;;
esac

second="$(bash "$HERE/trim.sh" "$TMP")"
case "$second" in
  *"verwijderd:"*) fail "tweede run meldde opnieuw verwijderingen" ;;
esac

echo "OK"
