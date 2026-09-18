# ECC-fork snoeien — implementatieplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** De fork `marnix-bf/ECC` terugbrengen tot 175 skills, 39 agents en 76 commands, met een herhaalbaar snoeiscript zodat updates uit de bovenstroom samengevoegd kunnen blijven worden.

**Architecture:** De selectie staat als data in `bf/keep-*.txt`. Een script `bf/trim.sh` verwijdert alles daarbuiten en meldt wat het weghaalt. Na elke `git merge upstream/main` draait het script opnieuw, zodat de snoei nooit als handmatige verwijderingen in de geschiedenis staat en dus niet botst.

**Tech Stack:** Bash, git, GitHub CLI, Claude Code plugin-marketplace.

**Spec:** `docs/superpowers/specs/2026-09-18-ecc-fork-design.md`

## Global Constraints

- Werk uitsluitend op branch `bf`. `main` volgt de bovenstroom ongewijzigd.
- `origin` = `https://github.com/marnix-bf/ECC.git`, `upstream` = `https://github.com/affaan-m/ECC.git`. Beide staan al goed.
- Geen inhoudelijke wijziging in de overgebleven skills, agents of commands. Dit plan gaat over selectie, configuratie en onderhoudbaarheid.
- Scripts zijn bash met `set -euo pipefail` en werken zonder GNU-specifieke vlaggen, want macOS levert bash 3.2.
- Alle nieuwe bestanden staan onder `bf/`, zodat samenvoegingen met de bovenstroom er nooit op botsen.
- Documentatie en commitberichten in het Nederlands, in lopende zinnen.
- De hook `pre:edit-write:gateguard-fact-force` staat tijdens de uitvoering nog aan en blokkeert de eerste bewerking per bestand. Dat is verwacht; beantwoord de poort en ga door. Task 4 zet hem uit.

---

### Task 1: Houdlijsten en het snoeiscript

**Files:**
- Create: `bf/keep-skills.txt`
- Create: `bf/keep-agents.txt`
- Create: `bf/keep-commands.txt`
- Create: `bf/drop-files.txt`
- Create: `bf/trim.sh`
- Test: `bf/trim.test.sh`

**Interfaces:**
- Consumes: niets.
- Produces: `bf/trim.sh [ROOT]` — verwijdert uit `ROOT/skills`, `ROOT/agents` en `ROOT/commands` alles dat niet in de bijbehorende houdlijst staat, plus elk pad in `bf/drop-files.txt`. `ROOT` is standaard de map boven `bf/`. Afsluitcode 0 bij succes, 1 als een houdlijst ontbreekt. Task 2 en 5 roepen het aan.

- [ ] **Step 1: Schrijf de falende test**

Maak `bf/trim.test.sh`:

```bash
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
```

- [ ] **Step 2: Draai de test en zie hem falen**

Run: `cd ~/Code/Repos/ECC && bash bf/trim.test.sh`
Expected: FAIL met `bash: .../bf/trim.sh: No such file or directory`

- [ ] **Step 3: Schrijf het snoeiscript**

Maak `bf/trim.sh`:

```bash
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
```

Maak beide scripts uitvoerbaar: `chmod +x bf/trim.sh bf/trim.test.sh`

- [ ] **Step 4: Draai de test en zie hem slagen**

Run: `cd ~/Code/Repos/ECC && bash bf/trim.test.sh`
Expected: `OK`

- [ ] **Step 5: Schrijf de houdlijst voor skills**

`bf/keep-skills.txt`, 175 regels, één naam per regel, exact deze en in deze volgorde:

```
orch-add-feature
orch-build-mvp
orch-change-feature
orch-fix-defect
orch-pipeline
orch-refine-code
tdd-workflow
verification-loop
delivery-gate
production-audit
security-review
security-bounty-hunter
safety-guard
gateguard
code-tour
codebase-onboarding
coding-standards
error-handling
api-design
contract-first
architecture-decision-records
hexagonal-architecture
backend-patterns
frontend-patterns
database-migrations
deployment-patterns
docker-patterns
git-workflow
github-ops
repo-scan
plankton-code-quality
inherit-legacy-style
intent-driven-development
blueprint
plan-canvas
plan-orchestrate
product-capability
product-lens
search-first
strategic-compact
living-docs-governance
documentation-lookup
opensource-pipeline
browser-qa
e2e-testing
ai-regression-testing
click-path-audit
terminal-ops
terminal-opener
react-patterns
react-performance
react-testing
nextjs-turbopack
vite-patterns
vue-patterns
nuxt4-patterns
ui-to-vue
angular-developer
bun-runtime
nestjs-patterns
prisma-patterns
postgres-patterns
mysql-patterns
redis-patterns
clickhouse-io
mcp-server-patterns
react-native-patterns
laravel-patterns
laravel-plugin-discovery
laravel-security
laravel-tdd
laravel-verification
accessibility
frontend-a11y
frontend-design-direction
frontend-slides
design-system
make-interfaces-feel-better
liquid-glass-design
ui-demo
motion-foundations
motion-patterns
motion-advanced
taste
taste-application
taste-distillation
tasteforge-video
video-editing
videodb
remotion-video-creation
manim-video
ios-icon-gen
fal-ai-media
seo
marketing-campaign
brand-discovery
brand-voice
content-engine
crosspost
social-publisher
social-graph-ranker
article-writing
competitive-platform-analysis
competitive-report-structure
market-research
lead-intelligence
growth-log
x-api
deep-research
research-ops
knowledge-ops
dashboard-builder
data-scraper-agent
exa-search
investor-materials
investor-outreach
agent-architecture-audit
agent-eval
agent-harness-construction
agent-introspection-debugging
agent-self-evaluation
agent-sort
agentic-engineering
agentic-os
ai-first-engineering
eval-harness
benchmark
benchmark-methodology
benchmark-optimization-loop
prompt-optimizer
skill-comply
skill-scout
skill-stocktake
rules-distill
hookify-rules
context-budget
token-budget-advisor
cost-tracking
cost-aware-llm-pipeline
continuous-learning
continuous-learning-v2
unified-memory
recursive-decision-ledger
council
council-multi-model
regex-vs-llm-structured-text
iterative-retrieval
codehealth-mcp
configure-ecc
ecc-guide
ecc-recipes
ecc-tools-cost-audit
config-gc
workspace-surface-audit
autonomous-agent-harness
autonomous-loops
continuous-agent-loop
dev-team
team-agent-orchestration
team-builder
gan-style-harness
santa-method
loop-design-check
operator-approval-loop
parallel-execution-optimizer
dynamic-workflow-mode
claude-devfleet
ralphinho-rfc-pipeline
email-ops
messages-ops
google-workspace-ops
unified-notifications-ops
project-flow-ops
jira-integration
mailtrap-email-integration
```

- [ ] **Step 6: Schrijf de houdlijst voor agents**

`bf/keep-agents.txt`, 39 regels:

```
typescript-reviewer
react-reviewer
react-build-resolver
vue-reviewer
php-reviewer
build-error-resolver
database-reviewer
code-reviewer
code-architect
code-explorer
code-simplifier
architect
planner
a11y-architect
security-reviewer
performance-optimizer
refactor-cleaner
tdd-guide
e2e-runner
pr-test-analyzer
silent-failure-hunter
type-design-analyzer
comment-analyzer
doc-updater
docs-lookup
spec-miner
marketing-agent
seo-specialist
agent-evaluator
harness-optimizer
loop-operator
chief-of-staff
conversation-analyzer
gan-planner
gan-generator
gan-evaluator
opensource-forker
opensource-packager
opensource-sanitizer
```

- [ ] **Step 7: Schrijf de houdlijst voor commands en de bestandenlijst**

`bf/keep-commands.txt`, 76 regels:

```
aside
auto-update
build-fix
checkpoint
code-review
cost-report
ecc-guide
epic-claim
epic-decompose
epic-publish
epic-review
epic-sync
epic-unblock
epic-validate
evolve
feature-dev
gan-build
gan-design
harness-audit
hookify-configure
hookify-help
hookify-list
hookify
instinct-export
instinct-import
instinct-status
jira
learn-eval
learn
loop-start
loop-status
marketing-campaign
model-route
multi-backend
multi-execute
multi-frontend
multi-plan
multi-workflow
orch-add-feature
orch-build-mvp
orch-change-feature
orch-fix-defect
orch-refine-code
orch-review
plan-canvas
plan-prd
plan
pm2
pr
project-init
projects
promote
prp-commit
prp-implement
prp-plan
prp-pr
prp-prd
prune
quality-gate
react-build
react-review
react-test
refactor-clean
resume-session
review-pr
santa-loop
save-session
security-scan
sessions
setup-pm
skill-create
skill-health
test-coverage
update-codemaps
update-docs
vue-review
```

`bf/drop-files.txt`:

```
scripts/hooks/insaits-security-monitor.py
scripts/hooks/insaits-security-wrapper.js
```

- [ ] **Step 8: Controleer dat elke naam in de houdlijsten bestaat**

Run:

```bash
cd ~/Code/Repos/ECC && ls skills | sort > /tmp/a.txt && sort bf/keep-skills.txt > /tmp/k.txt && echo "skills ontbrekend:" && comm -23 /tmp/k.txt /tmp/a.txt && ls agents | sed 's/\.md$//' | sort > /tmp/a.txt && sort bf/keep-agents.txt > /tmp/k.txt && echo "agents ontbrekend:" && comm -23 /tmp/k.txt /tmp/a.txt && ls commands | sed 's/\.md$//' | sort > /tmp/a.txt && sort bf/keep-commands.txt > /tmp/k.txt && echo "commands ontbrekend:" && comm -23 /tmp/k.txt /tmp/a.txt
```

Expected: onder elk van de drie koppen geen enkele regel. Verschijnt er een naam, dan staat er een typefout in de houdlijst; herstel die voordat je verder gaat.

- [ ] **Step 9: Leg vast**

```bash
cd ~/Code/Repos/ECC
git add bf/
git commit -m "feat: houdlijsten en snoeiscript voor de fork"
```

---

### Task 2: De snoei uitvoeren

**Files:**
- Modify: verwijdert 117 mappen onder `skills/`, 29 bestanden onder `agents/`, 18 onder `commands/` en twee onder `scripts/hooks/`.

**Interfaces:**
- Consumes: `bf/trim.sh` en de drie houdlijsten uit Task 1.
- Produces: een repository met 175 skills, 39 agents en 76 commands. Task 3 controleert de verwijzingen die daarin achterblijven.

- [ ] **Step 1: Tel vooraf**

Run: `cd ~/Code/Repos/ECC && echo "voor: skills=$(ls skills | wc -l) agents=$(ls agents | wc -l) commands=$(ls commands | wc -l)"`
Expected: `voor: skills=292 agents=68 commands=94`

- [ ] **Step 2: Draai het snoeiscript**

Run: `cd ~/Code/Repos/ECC && ./bf/trim.sh`
Expected: 166 regels `verwijderd: …`, afgesloten met `klaar: 166 verwijderd`.

- [ ] **Step 3: Tel achteraf**

Run: `cd ~/Code/Repos/ECC && echo "na: skills=$(ls skills | wc -l) agents=$(ls agents | wc -l) commands=$(ls commands | wc -l)"`
Expected: `na: skills=175 agents=39 commands=76`

- [ ] **Step 4: Controleer dat een tweede run niets meer doet**

Run: `cd ~/Code/Repos/ECC && ./bf/trim.sh`
Expected: `klaar: 0 verwijderd`, zonder `verwijderd:`-regels.

- [ ] **Step 5: Leg vast**

```bash
cd ~/Code/Repos/ECC
git add -A skills agents commands scripts
git commit -m "chore: snoei skills, agents en commands terug tot de eigen selectie"
```

---

### Task 3: Verwijzingen naar verdwenen onderdelen opruimen

**Files:**
- Create: `bf/verwijderd.txt`
- Create: `bf/check-refs.sh`
- Modify: `docs/COMMAND-AGENT-MAP.md`
- Modify: `docs/COMMAND-REGISTRY.json`
- Modify: elk overgebleven bestand dat naar een verwijderde naam verwijst, gevonden in Step 3

**Interfaces:**
- Consumes: de gesnoeide boom uit Task 2.
- Produces: `bf/check-refs.sh [ROOT]` — afsluitcode 0 als geen overgebleven bestand nog naar een verwijderde naam verwijst, anders 1 met een lijst. Task 5 draait het opnieuw als eindcontrole.

- [ ] **Step 1: Leg de lijst met verwijderde namen vast**

Run:

```bash
cd ~/Code/Repos/ECC && git diff --name-only --diff-filter=D HEAD~1 HEAD | awk -F/ '$1=="skills"{print $2} $1=="agents"||$1=="commands"{sub(/\.md$/,"",$2); print $2}' | sort -u > bf/verwijderd.txt && wc -l < bf/verwijderd.txt
```

Expected: `164` — 117 skills, 29 agents en 18 commands.

- [ ] **Step 2: Schrijf het controlescript**

Maak `bf/check-refs.sh`:

```bash
#!/usr/bin/env bash
# Meldt verwijzingen naar skills, agents of commands die niet meer bestaan.
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BF="$ROOT/bf"

hits=0
while IFS= read -r naam; do
  [ -n "$naam" ] || continue
  treffers="$(grep -rlF --exclude-dir=.git --exclude-dir=bf --exclude-dir=node_modules --exclude-dir=docs/superpowers "$naam" "$ROOT" 2>/dev/null || true)"
  if [ -n "$treffers" ]; then
    echo "nog verwezen: $naam"
    echo "$treffers" | sed 's/^/    /'
    hits=$((hits + 1))
  fi
done < "$BF/verwijderd.txt"

echo "totaal nog verwezen: $hits"
[ "$hits" -eq 0 ]
```

Maak het uitvoerbaar: `chmod +x bf/check-refs.sh`

- [ ] **Step 3: Draai de controle en zie hem falen**

Run: `cd ~/Code/Repos/ECC && bash bf/check-refs.sh`
Expected: FAIL met een lijst. `docs/COMMAND-AGENT-MAP.md` en `docs/COMMAND-REGISTRY.json` staan er zeker bij, want die noemen elk command en elke agent.

- [ ] **Step 4: Herstel de twee registerbestanden**

Verwijder uit `docs/COMMAND-AGENT-MAP.md` elke tabelregel waarvan de command- of agentnaam in `bf/verwijderd.txt` staat. Verwijder uit `docs/COMMAND-REGISTRY.json` elk item waarvan het `name`-veld daarin staat.

Controleer daarna de JSON:

```bash
cd ~/Code/Repos/ECC && python3 -m json.tool docs/COMMAND-REGISTRY.json > /dev/null && echo "JSON geldig"
```

Expected: `JSON geldig`

- [ ] **Step 5: Beoordeel de overige treffers**

Per resterende treffer geldt één van drie gevallen. Staat de naam in lopende tekst van een skill die blijft, herschrijf die zin zonder de verwijzing. Gaat een heel document over een verdwenen taal of vakgebied, voeg het pad dan toe aan `bf/drop-files.txt` en draai `./bf/trim.sh` opnieuw. Is de treffer toevallig — een gewoon woord dat ook een skillnaam is, zoals `benchmark` of `taste` — laat hem dan staan en voeg de naam toe aan een uitzonderingsregel boven in `bf/verwijderd.txt` door hem eruit te halen.

- [ ] **Step 6: Draai de controle tot hij slaagt**

Run: `cd ~/Code/Repos/ECC && bash bf/check-refs.sh`
Expected: `totaal nog verwezen: 0` en afsluitcode 0.

- [ ] **Step 7: Leg vast**

```bash
cd ~/Code/Repos/ECC
git add -A
git commit -m "fix: verwijzingen naar verwijderde skills, agents en commands opgeruimd"
```

---

### Task 4: Plugin-identiteit, hookconfiguratie en handleiding

**Files:**
- Modify: `.claude-plugin/marketplace.json`
- Create: `bf/README.md`
- Modify: `~/.claude/settings.json` (buiten de repo)

**Interfaces:**
- Consumes: de opgeschoonde boom uit Task 3.
- Produces: een installeerbare plugin met eigen naam en de hookinstellingen uit §3 van de spec. Task 5 installeert en verifieert die.

- [ ] **Step 1: Pas de marketplace aan**

Wijzig in `.claude-plugin/marketplace.json`: `owner.name` naar `Marnix`, `owner.email` naar `marnix@blueflamingos.nl`, `plugins[0].author` op dezelfde twee waarden, `plugins[0].repository` naar `https://github.com/marnix-bf/ECC`, en `plugins[0].description` naar `Gesnoeide ECC-fork — 39 agents, 175 skills, 76 commands, afgestemd op TypeScript, React, Next.js, Strapi en Node`. Laat `name`, `source`, `version` en `homepage` ongemoeid, zodat de plugin-identiteit binnen Claude Code gelijk blijft.

- [ ] **Step 2: Controleer de JSON**

Run: `cd ~/Code/Repos/ECC && python3 -m json.tool .claude-plugin/marketplace.json > /dev/null && echo "JSON geldig"`
Expected: `JSON geldig`

- [ ] **Step 3: Zet de hookinstellingen in de gebruikersinstellingen**

`ECC_DISABLED_HOOKS` wordt alleen uit de omgeving gelezen — zie `getDisabledHookIds` in `scripts/lib/hook-flags.js:86` — en niet uit `ecc/setup.json`, dat alleen `enabled` en `profile` kent. De instelling hoort daarom in `~/.claude/settings.json`. Voeg dit `env`-blok toe, of vul een bestaand blok aan:

```json
{
  "env": {
    "ECC_HOOK_PROFILE": "standard",
    "ECC_DISABLED_HOOKS": "pre:bash:auto-tmux-dev,pre:bash:tmux-reminder,pre:powershell:gateguard-fact-force,pre:edit-write:gateguard-fact-force,pre:write:doc-file-warning"
  }
}
```

- [ ] **Step 4: Controleer de instellingen**

Run: `python3 -m json.tool ~/.claude/settings.json > /dev/null && echo "JSON geldig"`
Expected: `JSON geldig`

- [ ] **Step 5: Schrijf de handleiding**

Maak `bf/README.md` met vijf onderdelen, elk een korte alinea in lopende zinnen:

1. Waarom deze fork bestaat, met een verwijzing naar `docs/superpowers/specs/2026-09-18-ecc-fork-design.md`.
2. Installeren: `/plugin marketplace add ~/Code/Repos/ECC`, gevolgd door het installeren van de plugin `ecc`.
3. Bijwerken uit de bovenstroom, met het commando `git checkout bf && git merge upstream/main && ./bf/trim.sh && git commit -am "trim"` en de opmerking dat conflicten alleen nog ontstaan op `.claude-plugin/marketplace.json` en op bestanden onder `docs/` die zelf zijn aangepast.
4. Een skill terughalen: naam toevoegen aan de houdlijst, dan `git checkout upstream/main -- skills/<naam>`.
5. De hookinstellingen uit Step 3, met per uitgezette identiteit één zin over de reden: de twee tmux-hooks omdat tmux hier niet gebruikt wordt, de PowerShell-poort omdat die Windows-alleen is, de fact-forcing-poort op Edit omdat die elke eerste bewerking per bestand blokkeert, en de documentwaarschuwing omdat die niets toevoegt. Vermeld erbij dat de fact-forcing-poort op Bash juist wél aan blijft.

- [ ] **Step 6: Leg vast**

```bash
cd ~/Code/Repos/ECC
git add .claude-plugin/marketplace.json bf/README.md
git commit -m "feat: eigen plugin-identiteit en handleiding voor de fork"
```

---

### Task 5: Installeren en verifiëren

**Files:**
- Modify: `docs/superpowers/specs/2026-09-18-ecc-fork-design.md`

**Interfaces:**
- Consumes: alles uit Task 1 tot en met 4.
- Produces: een draaiende plugin en een spec waarvan de aantallen kloppen. Task 6 kan pas beginnen als dit slaagt.

- [ ] **Step 1: Verwijder de oude installatie**

De plugin draait nu vanaf de marketplace `ecc`. Verwijder die eerst, anders staan twee kopieën naast elkaar: `/plugin marketplace remove ecc`

- [ ] **Step 2: Installeer de fork vanaf het lokale pad**

Run in Claude Code: `/plugin marketplace add ~/Code/Repos/ECC`, daarna de plugin `ecc` installeren.
Expected: geen laadfouten.

- [ ] **Step 3: Controleer de zichtbare selectie**

Start een nieuwe sessie en bekijk de skill-lijst. `healthcare-emr-patterns`, `homelab-vlan-segmentation`, `rust-patterns` en `springboot-security` mogen niet meer voorkomen. `orch-add-feature`, `react-patterns`, `laravel-tdd` en `seo` moeten er wel staan.

- [ ] **Step 4: Controleer twee commands**

Run in Claude Code: `/ecc-guide`, daarna `/orch-add-feature` met een triviale opdracht.
Expected: beide starten zonder fout over een ontbrekende skill of agent.

- [ ] **Step 5: Controleer de hooks**

Draai een willekeurig Bash-commando: de fact-forcing-poort op Bash hoort te vuren. Bewerk daarna een bestaand bestand: de poort op Edit hoort niet te vuren.
Expected: precies dat. Vuurt de Edit-poort toch, dan is het `env`-blok uit Task 4 niet geladen; herstart Claude Code en probeer opnieuw.

- [ ] **Step 6: Draai de verwijzingscontrole nog eens**

Run: `cd ~/Code/Repos/ECC && bash bf/check-refs.sh`
Expected: `totaal nog verwezen: 0`

- [ ] **Step 7: Corrigeer de spec**

Werk `docs/superpowers/specs/2026-09-18-ecc-fork-design.md` bij op drie punten. Vervang in §2 "128 skills en 31 agents" door "117 skills, 29 agents en 18 commands". Vervang "Ongeveer 164 van de 292 skills en 37 van de 68 agents" door "175 van de 292 skills en 39 van de 68 agents". Voeg aan §2 een alinea toe over de commands: de achttien die bij verdwenen talen horen — `cpp-build`, `cpp-review`, `cpp-test`, `fastapi-review`, `flutter-build`, `flutter-review`, `flutter-test`, `go-build`, `go-review`, `go-test`, `gradle-build`, `kotlin-build`, `kotlin-review`, `kotlin-test`, `python-review`, `rust-build`, `rust-review` en `rust-test` — vervallen, de overige 76 blijven. Vermeld in §3 dat `ECC_DISABLED_HOOKS` alleen uit de omgeving gelezen wordt en daarom in `~/.claude/settings.json` staat en niet in de fork.

- [ ] **Step 8: Leg vast en push**

```bash
cd ~/Code/Repos/ECC
git add docs/superpowers/specs/2026-09-18-ecc-fork-design.md
git commit -m "docs: spec bijgewerkt met de werkelijke aantallen en de commands"
git push origin bf
```

---

### Task 6: goat afbouwen

**Files:**
- Modify: `~/Code/Repos/goat/README.md`
- Modify: `~/Code/Repos/goat/CHANGELOG.md`

**Interfaces:**
- Consumes: een werkende fork uit Task 5.
- Produces: niets waar latere taken op bouwen; dit is de laatste taak.

- [ ] **Step 1: Zet de status in de README**

Voeg in `~/Code/Repos/goat/README.md`, direct onder de titel en boven de lijst met documenten, een kop **Gestopt** toe met twee zinnen: het project is per 2026-09-18 gestopt ten gunste van de gesnoeide ECC-fork in `~/Code/Repos/ECC`, en de repository blijft een maand staan voordat hij gearchiveerd wordt. Verwijs naar `docs/superpowers/specs/2026-09-18-ecc-fork-design.md` in die fork.

- [ ] **Step 2: Sluit het changelog af**

Voeg boven aan `~/Code/Repos/goat/CHANGELOG.md` een kopje toe voor 2026-09-18 met één regel: het project stopt na Fase 4 en Fase 5 vervalt, omdat het orkestratiewerk naar de ECC-fork verhuist.

- [ ] **Step 3: Leg vast op een eigen branch**

```bash
cd ~/Code/Repos/goat
git checkout -b stop-project
git add README.md CHANGELOG.md
git commit -m "docs: project gestopt ten gunste van de ECC-fork"
git push -u origin stop-project
```

- [ ] **Step 4: Open de pull request**

```bash
cd ~/Code/Repos/goat && gh pr create --title "Project gestopt ten gunste van de ECC-fork" --body "goat krijgt geen nieuwe functies meer en Fase 5 vervalt. Het orkestratiewerk verhuist naar de gesnoeide ECC-fork in ~/Code/Repos/ECC. De repository blijft een maand staan voordat hij gearchiveerd wordt."
```

---

## Zelfcontrole

**Dekking van de spec.** §1 over de repo-vorm valt onder Task 4 en 5; de remotes stonden al goed voordat dit plan begon. §2 over het snoeien valt onder Task 1 tot en met 3. §3 over de hooks valt onder Task 4. §4 over de afbouw van goat valt onder Task 6. §5 over de verificatie valt onder Task 5, waar de vijf punten terugkomen als Step 3 tot en met 6.

**Gaten die dit plan zelf dicht.** De spec noemde de commands niet en gaf te lage aantallen; Task 5 Step 7 corrigeert beide in de spec zelf. De spec ging ervan uit dat de hookinstellingen in de fork konden staan; Task 4 Step 3 zet ze in `~/.claude/settings.json` en legt uit waarom dat moet.

**Namen.** `bf/trim.sh` heet in elke taak zo en neemt overal dezelfde parameter `ROOT`. De houdlijsten heten overal `bf/keep-skills.txt`, `bf/keep-agents.txt` en `bf/keep-commands.txt`. `bf/verwijderd.txt` wordt aangemaakt in Task 3 Step 1 en gelezen door `bf/check-refs.sh` uit Step 2 van dezelfde taak. `bf/drop-files.txt` wordt aangemaakt in Task 1 Step 7 en aangevuld in Task 3 Step 5.
