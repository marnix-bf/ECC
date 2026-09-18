# De gesnoeide fork

Deze fork van [affaan-m/ECC](https://github.com/affaan-m/ECC) is teruggebracht
tot wat past bij één ontwikkelaar die in TypeScript, React, Next.js, Strapi en
Node werkt. De bovenstroom levert 292 skills, 68 agents en 94 commands over
vrijwel elk vakgebied; daarvan blijven er hier 176, 39 en 76 over. De redenering
achter die selectie staat in
[het ontwerp](../docs/superpowers/specs/2026-09-18-ecc-fork-design.md), de
uitvoering in
[het plan](../docs/superpowers/plans/2026-09-18-ecc-fork-trim.md).

## Installeren

Voeg de repository als marketplace toe en installeer de plugin `ecc`:

```
/plugin marketplace add ~/Code/Repos/ECC
```

Het lokale pad werkt sneller dan de GitHub-bron: een wijziging op schijf is
meteen zichtbaar, zonder push.

## Bijwerken uit de bovenstroom

```bash
git checkout bf
git merge upstream/main
./bf/trim.sh
git commit -am "trim"
```

`trim.sh` verwijdert alles wat niet in de houdlijsten staat en drukt af wat het
weghaalde. Nieuwe skills uit de bovenstroom verschijnen in die uitvoer, zodat je
bewust kunt beslissen of je ze wilt. Conflicten ontstaan alleen nog op bestanden
die hier zelf zijn aangepast: `.claude-plugin/marketplace.json`, de drie
manifesten, `config/project-stack-mappings.json`,
`workflows/orch-review.workflow.js` en een handvol skills waaruit dode
tabelregels zijn gehaald.

Draai daarna `./bf/check-refs.sh`. Dat meldt of een overgebleven skill, command,
werkstroom of script nog naar iets verwijst dat niet meer bestaat.

## Een skill terughalen

Voeg de naam toe aan de bijbehorende houdlijst en haal het bestand terug uit de
bovenstroom met `git checkout upstream/main -- skills/<naam>`.

## De bestanden hier

| Bestand | Waarvoor |
|---|---|
| `keep-skills.txt` | 176 skills die blijven |
| `keep-agents.txt` | 39 agents die blijven |
| `keep-commands.txt` | 76 commands die blijven |
| `drop-files.txt` | losse paden die altijd weg moeten: andere harnesses, vertalingen, regelpakketten van verdwenen talen |
| `verwijderd.txt` | de namen die gesnoeid zijn; voer voor `check-refs.sh` |
| `refs-ok.txt` | namen die alleen nog in lopende tekst voorkomen en niets aansturen |
| `trim.sh` | het snoeiscript |
| `check-refs.sh` | de controle op dode verwijzingen |
| `trim.test.sh` | test voor `trim.sh`, draait op een neptree |

## De hooks

ECC leest `ECC_DISABLED_HOOKS` alleen uit de omgeving — zie `getDisabledHookIds`
in `scripts/lib/hook-flags.js` — en niet uit een bestand in de plugin. De
instelling staat daarom in `~/.claude/settings.json`:

```json
{
  "env": {
    "ECC_HOOK_PROFILE": "standard",
    "ECC_DISABLED_HOOKS": "pre:bash:auto-tmux-dev,pre:bash:tmux-reminder,pre:powershell:gateguard-fact-force,pre:edit-write:gateguard-fact-force,pre:write:doc-file-warning"
  }
}
```

Waarom deze vijf uit staan: de twee tmux-hooks omdat tmux hier niet gebruikt
wordt, de PowerShell-poort omdat die alleen op Windows zin heeft, de
fact-forcing-poort op Edit en Write omdat die elke eerste bewerking per bestand
blokkeert, en de waarschuwing over documentbestanden omdat die niets toevoegt.

De fact-forcing-poort op Bash blijft juist wél aan, net als de herinnering rond
pushen, het voorstel tot compacteren, beide Plan Canvas-hooks, de
bureaubladmelding, het opmaken en typecontroleren bij Stop, de kwaliteitspoort,
de kostenteller en de MCP-gezondheidscontrole.
