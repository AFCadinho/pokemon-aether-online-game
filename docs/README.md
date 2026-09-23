# Documentatiekaart (frontend)

Begin voor werk in deze repository bij [`AGENTS.md`](../AGENTS.md) en
[`WORKFLOW.md`](../WORKFLOW.md). De procedures voor werktrees, integratie en
vrijgave staan in de gekoppelde `game/ops/`-map; oude handoffs zijn daarvoor
geen vervanging.

## Actuele ingang per onderwerp

- Content packs: [`content-packs.md`](content-packs.md) en de voorbeelden onder
  [`examples/content-packs/`](examples/content-packs/).
- Goedgekeurde optionele 3D-bundels:
  [`approved-3d-bundle-release.md`](approved-3d-bundle-release.md).
- Lokalisatie: [`localization_conventions.md`](localization_conventions.md).
- Handmatige spelcontrole: [`manual-end-to-end-testguide.md`](manual-end-to-end-testguide.md).
- Sprites: [`tools/sprite_factory/README.md`](../tools/sprite_factory/README.md).
- Kaart-atlassen: de huidige import en compactie staan onder
  [`addons/tiled_tmx_importer/importer/`](../addons/tiled_tmx_importer/importer/);
  de opslagvorm wordt gecontroleerd door
  [`generated_map_texture_storage_check.gd`](../tests/generated_map_texture_storage_check.gd).

## Historische stukken en checks

De fase-, proef-, audit- en handoffdocumenten in deze map leggen besluiten en
testresultaten op een bepaald moment vast. Controleer hun datum en de huidige
code voordat je ze als werkinstructie gebruikt. De
[`PvP-ranked-handoff`](pvp_ranked_handoff.md) verwijst naar de bewaarde
backendkopie.

`tests/run_project_checks.gd` is de brede projectrunner; daarnaast bestaan
gerichte checks en tests die afzonderlijk of via workflows worden gestart.
Een check die niet in de brede runner staat, is daarom niet automatisch
overbodig. Gebruik voor een taak alleen de relevante checks in het toegewezen
slot; zie `AGENTS.md`.
