# ECC-fork voor Blue Flamingos — ontwerp

Datum: 2026-09-18
Status: goedgekeurd, klaar voor implementatieplan

## Aanleiding

ECC (`affaan-m/ECC`, v2.2.1) levert 68 agents, 292 skills, 94 commands en een
hooklaag van ongeveer vijftig scripts. De inhoud is breed genoeg om vrijwel elk
vakgebied te dekken: gezondheidszorg, thuisnetwerken, wetenschappelijke
databases, crypto, logistiek, en een stuk of tien programmeertalen. Voor één
ontwikkelaar die uitsluitend in TypeScript, React, Next.js, Strapi en Node werkt
is dat vooral ruis. Elke skillnaam en -beschrijving wordt per sessie geladen, dus
de breedte kost context in elk gesprek, ook als je er niets mee doet.

Doel van deze fork: ECC terugbrengen tot wat bij dit werk past, zonder de band
met de bovenstroom te verliezen.

## Besluiten die aan dit ontwerp voorafgingen

- ECC vervangt `goat`. Het orkestratiewerk verhuist van een eigen Electron-app
  naar de ECC-pijplijn binnen Claude Code-sessies.
- Het verlies van goat's venster, takenwachtrij, worktree-beheer en PR-viewer
  wordt geaccepteerd. Al het werk gebeurt voortaan in de sessie.
- De GitHub-gebonden onderdelen van ECC (`epic-*`, `/pr`, `github-ops`, `prp-*`)
  blijven ongewijzigd en worden gebruikt voor de GitHub-repositories. Voor
  Uitgekookt, dat op Azure DevOps draait, blijven de bestaande
  `uitgekookt`-skills met de `azure-devops` MCP-server in gebruik. Er komt geen
  Azure DevOps-variant van de epic-familie.
- De marketing-, SEO- en contentfamilie blijft, evenals de meta-laag rond agents
  en skills, de familie met autonome loops en teams, en de familie rond motion,
  video en visueel ontwerp.

## 1. Repo-vorm

`affaan-m/ECC` wordt geforkt. De bestaande clone in `~/Code/Repos/ECC` krijgt
twee remotes: `origin` wijst naar de fork, `upstream` naar `affaan-m/ECC`.

- `main` volgt de bovenstroom ongewijzigd en wordt niet bewerkt.
- `bf` draagt al het eigen werk en is de branch waar de plugin uit geladen wordt.

`.claude-plugin/marketplace.json` krijgt de eigen naam en eigenaar. De
plugin-bron blijft `./`, zodat de hele repository de plugin is. Installeren
gebeurt via het lokale pad (`/plugin marketplace add ~/Code/Repos/ECC`), niet via
GitHub, zodat een wijziging meteen zichtbaar is zonder push.

## 2. Snoeien als script, niet als losse verwijderingen

Met de hand 116 skills, 29 agents en 18 commands verwijderen maakt elke
samenvoeging met de bovenstroom tot een conflictenveld. Daarom wordt de snoei uitgedrukt als data
plus een script:

- `bf/keep-skills.txt`, `bf/keep-agents.txt` en `bf/keep-commands.txt` — de
  houdlijsten: elke naam die blijft, één per regel.
- `bf/drop-files.txt` — losse paden die altijd weg moeten.
- `bf/trim.sh` — verwijdert alles onder `skills/`, `agents/` en `commands/` dat
  niet in de bijbehorende houdlijst staat, plus elk pad uit `drop-files.txt`.
- `bf/check-refs.sh` — meldt of een overgebleven bestand nog naar iets verwijst
  dat niet meer bestaat.

Bij een update uit de bovenstroom:

```bash
git checkout bf && git merge upstream/main && ./bf/trim.sh && git commit -am "trim"
```

Conflicten ontstaan dan alleen nog op bestanden die zelf zijn aangepast — de
manifesten, `marketplace.json`, de werkstroom en een handvol skills — en niet op
de 116 verwijderde skills.
`trim.sh` drukt af welke nieuwe namen het tegenkwam die niet in de houdlijst
staan, zodat een nieuwe upstream-skill een bewuste keuze wordt in plaats van een
stille verdwijning.

### Wat blijft

176 van de 292 skills, 39 van de 68 agents en 76 van de 94 commands.

**Kern-engineering.** De zes `orch-*` skills, `tdd-workflow`,
`verification-loop`, `delivery-gate`, `quality-gate`, `production-audit`,
`security-review`, `security-scan`, `security-bounty-hunter`, `safety-guard`,
`gateguard`, `code-tour`, `codebase-onboarding`, `coding-standards`,
`error-handling`, `api-design`, `contract-first`,
`architecture-decision-records`, `hexagonal-architecture`, `backend-patterns`,
`frontend-patterns`, `database-migrations`, `deployment-patterns`,
`docker-patterns`, `git-workflow`, `github-ops`, `repo-scan`,
`plankton-code-quality`, `inherit-legacy-style`, `intent-driven-development`,
`blueprint`, `plan-canvas`, `plan-orchestrate`, `product-capability`,
`product-lens`, `search-first`, `strategic-compact`, `living-docs-governance`,
`documentation-lookup`, `opensource-pipeline`, `browser-qa`, `e2e-testing`,
`ai-regression-testing`, `click-path-audit` en `terminal-ops`.

**De eigen stack.** `react-patterns`, `react-performance`, `react-testing`,
`nextjs-turbopack`, `vite-patterns`, `vue-patterns`, `nuxt4-patterns`,
`ui-to-vue`, `angular-developer`, `bun-runtime`, `nestjs-patterns`,
`prisma-patterns`, `postgres-patterns`, `mysql-patterns`, `redis-patterns`,
`clickhouse-io`, `mcp-server-patterns` en `react-native-patterns`. Daarnaast
blijft de Laravel-familie (`laravel-patterns`, `laravel-plugin-discovery`,
`laravel-security`, `laravel-tdd`, `laravel-verification`) staan voor
`weflycheap-api`, de enige repository met PHP.

**Frontend, ontwerp en motion.** `accessibility`, `frontend-a11y`,
`frontend-design-direction`, `frontend-slides`, `design-system`,
`make-interfaces-feel-better`, `liquid-glass-design`, `ui-demo`, de drie
`motion-*` skills, `taste`, `taste-application`, `taste-distillation`,
`tasteforge-video`, `video-editing`, `videodb`, `remotion-video-creation`,
`manim-video`, `ios-icon-gen` en `fal-ai-media`.

**Marketing, content en onderzoek.** `seo`, `marketing-campaign`,
`brand-discovery`, `brand-voice`, `content-engine`, `crosspost`,
`social-publisher`, `social-graph-ranker`, `article-writing`,
`competitive-platform-analysis`, `competitive-report-structure`,
`market-research`, `lead-intelligence`, `growth-log`, `x-api`, `deep-research`,
`research-ops`, `knowledge-ops`, `dashboard-builder`, `data-scraper-agent`,
`exa-search`, `investor-materials` en `investor-outreach`.

**De meta-laag rond agents en skills.** `agent-architecture-audit`,
`agent-eval`, `agent-harness-construction`, `agent-introspection-debugging`,
`agent-self-evaluation`, `agent-sort`, `agentic-engineering`, `agentic-os`,
`ai-first-engineering`, `eval-harness`, de drie `benchmark*` skills,
`prompt-optimizer`, `skill-comply`, `skill-scout`, `skill-stocktake`,
`rules-distill`, `hookify-rules`, `context-budget`, `token-budget-advisor`,
`cost-tracking`, `cost-aware-llm-pipeline`, beide `continuous-learning`-skills,
`unified-memory`, `recursive-decision-ledger`, `council`, `council-multi-model`,
`regex-vs-llm-structured-text`, `iterative-retrieval`, `codehealth-mcp`,
`configure-ecc`, `ecc-guide`, `ecc-recipes`, `ecc-tools-cost-audit`, `config-gc`
en `workspace-surface-audit`.

**Loops en teams.** `autonomous-agent-harness`, `autonomous-loops`,
`continuous-agent-loop`, `dev-team`, `team-agent-orchestration`, `team-builder`,
`gan-style-harness`, `santa-method`, `loop-design-check`,
`operator-approval-loop`, `parallel-execution-optimizer`,
`dynamic-workflow-mode`, `claude-devfleet` en `ralphinho-rfc-pipeline`.

**Werkstroom en communicatie.** `email-ops`, `messages-ops`,
`google-workspace-ops`, `unified-notifications-ops`, `project-flow-ops`,
`jira-integration` en `mailtrap-email-integration`.

**Agents.** `typescript-reviewer`, `react-reviewer`, `react-build-resolver`,
`vue-reviewer`, `php-reviewer`, `build-error-resolver`, `database-reviewer`,
`code-reviewer`, `code-architect`, `code-explorer`, `code-simplifier`,
`architect`, `planner`, `a11y-architect`, `security-reviewer`,
`performance-optimizer`, `refactor-cleaner`, `tdd-guide`, `e2e-runner`,
`pr-test-analyzer`, `silent-failure-hunter`, `type-design-analyzer`,
`comment-analyzer`, `doc-updater`, `docs-lookup`, `spec-miner`,
`marketing-agent`, `seo-specialist`, `agent-evaluator`, `harness-optimizer`,
`loop-operator`, `chief-of-staff`, `conversation-analyzer`, de drie `gan-*`
agents en de drie `opensource-*` agents.

### Wat weggaat

**Andere talen en frameworks.** De families rond C++, C#, F#, Go, Java (inclusief
`jpa-patterns`, Spring Boot en Quarkus), Kotlin, Android, Compose Multiplatform,
Swift, SwiftUI, `foundation-models-on-device`, Dart en Flutter, Rust, Perl,
Python (inclusief `pytorch-patterns` en de Django-familie), `fastapi-patterns`,
`rails-patterns`, `tinystruct-patterns`, `generating-python-installer`,
`windows-desktop-e2e` en `hermes-imports`.

**Vakgebieden die hier niet spelen.** Gezondheidszorg en `hipaa-compliance`, de
thuislab-familie, netwerkbeheer (`network-*`, `cisco-ios-patterns`,
`netmiko-ssh-automation`), de wetenschappelijke databases, crypto en handel
(`defi-amm-security`, `evm-token-decimals`, `nodejs-keccak256`,
`llm-trading-agent-security`, `prediction-market-*`, `agent-payment-x402`), de
vier `ito-*` skills, logistiek en productie (`carrier-*`, `customs-*`,
`logistics-*`, `inventory-*`, `production-scheduling`, `returns-*`,
`quality-nonconformance`), `energy-procurement`,
`counterparty-channel-discipline`, `master-agreement-generator`,
`esign-field-placement`, `visa-doc-translate`, `finance-billing-ops`,
`customer-billing-ops`, `connections-optimizer` en de machine-learning-familie
(`mle-workflow`, `ml-adoption-playbook`, `recsys-pipeline-architect`,
`latency-critical-systems`, `data-throughput-accelerator`).

**Eigen projecten van de auteur.** `nanoclaw-repl`, `nasiko-control-plane`,
`openclaw-persona-forge`, `uncloud` en `ck`. Ook `dmux-workflows` en
`flox-environments` vallen af: beide veronderstellen een terminalomgeving die
hier niet gebruikt wordt.

**Commands.** Achttien commands horen bij verdwenen talen en vervallen:
`cpp-build`, `cpp-review`, `cpp-test`, `fastapi-review`, `flutter-build`,
`flutter-review`, `flutter-test`, `go-build`, `go-review`, `go-test`,
`gradle-build`, `kotlin-build`, `kotlin-review`, `kotlin-test`, `python-review`,
`rust-build`, `rust-review` en `rust-test`. De overige 76 blijven.

**Andere harnesses en vertalingen.** Tijdens de uitvoering bleek de ruis groter
dan de skills alleen. Weg gaan daarom ook de configuratiemappen van andere
harnesses (`.codex`, `.codex-plugin`, `.cursor`, `.gemini`, `.kiro`,
`.opencode`, `.qwen`, `.trae`, `.zed`) met hun gidsen in `docs/`, de zeven
vertaalde documentatiemappen met `README.zh-CN.md`, de regelpakketten van
verdwenen talen onder `rules/`, en `legacy-command-shims`, `docker` en
`integrations`. Dat scheelt ruim 280.000 regels.

**Agents.** De reviewers en build-resolvers van de weggevallen talen, de
`healthcare-reviewer`, `homelab-architect`, de drie netwerkagents, de
`mle-reviewer` en de `rag-pipeline-reviewer`.

## 3. Hooks

De hooklaag blijft grotendeels aan. ECC regelt dit met een profiel en een lijst
uitgeschakelde identiteiten, dus dit is configuratie, geen snoeiwerk. Die lijst
wordt alleen uit de omgeving gelezen — zie `getDisabledHookIds` in
`scripts/lib/hook-flags.js` — en niet uit `ecc/setup.json`, dat enkel `enabled`
en `profile` kent. De instelling staat daarom in `~/.claude/settings.json` en
niet in de fork:

```
ECC_HOOK_PROFILE=standard
ECC_DISABLED_HOOKS=pre:bash:auto-tmux-dev,pre:bash:tmux-reminder,pre:powershell:gateguard-fact-force,pre:edit-write:gateguard-fact-force,pre:write:doc-file-warning
```

De twee tmux-hooks vallen af omdat tmux hier niet gebruikt wordt. De
PowerShell-poort is Windows-alleen. De fact-forcing-poort op Edit en Write valt
af omdat die elke eerste bewerking per bestand blokkeert; de variant op Bash
blijft juist wél aan. De waarschuwing over documentbestanden voegt niets toe.

Alles wat niet in die lijst staat blijft actief, inclusief de
fact-forcing-poort op Bash, de herinnering rond pushen, het voorstel tot
compacteren, beide Plan Canvas-hooks en de bureaubladmelding. Het opmaken en
typecontroleren bij Stop, de kwaliteitspoort, de kostenteller en de
MCP-gezondheidscontrole blijven ook staan.

Twee bestanden worden wel verwijderd, omdat ze bij een ander project van de
auteur horen: `scripts/hooks/insaits-security-monitor.py` en
`scripts/hooks/insaits-security-wrapper.js`.

## 4. Afbouw van goat

`goat` blijft als repository bestaan maar krijgt geen nieuwe functies meer. Fase 5
vervalt. `CHANGELOG.md` krijgt een slotregel en `README.md` een kop die vermeldt
dat het project is gestopt ten gunste van deze fork. Archiveren gebeurt pas
nadat de fork een maand in gebruik is, zodat terugvallen mogelijk blijft.

Eén punt om in de gaten te houden: goat bood parallelle worktrees en een
PR-viewer in een eigen venster. ECC benadert dat met
`parallel-execution-optimizer`, `autonomous-loops` en `/review-pr`, maar dat
blijft werk binnen één sessie. Valt dat tegen, dan is `claude-devfleet` het
dichtstbijzijnde alternatief.

## 5. Verificatie

Na het snoeien wordt gecontroleerd dat:

1. de plugin zonder fouten laadt;
2. `/ecc-guide` en `/orch-add-feature` werken;
3. geen overgebleven `SKILL.md` verwijst naar een verwijderde skill of agent,
   gecontroleerd met een grep op alle weggegooide namen;
4. de hooks vuren zoals ingesteld — de Bash-poort wel, de Edit-poort niet;
5. het aantal skills en agents in `marketplace.json` overeenkomt met wat er
   werkelijk staat.

## Wat buiten dit ontwerp valt

Er komt geen Azure DevOps-variant van de epic-familie, geen vervanging voor
goat's venster, en geen aanpassing van de inhoud van de overgebleven skills. Dit
ontwerp gaat uitsluitend over selectie, configuratie en het onderhoudbaar houden
van de band met de bovenstroom.
