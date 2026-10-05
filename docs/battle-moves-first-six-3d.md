# Eerste zes native 3D-moves

Geïmplementeerd; alle zes wachten op visuele goedkeuring. De bestaande
Pokémon-aanvalsclips en algemene damage/status-effecten blijven in gebruik.

- [ ] **Tackle** — korte bewegingsstrepen en een compacte contactinslag.
- [ ] **Scratch** — drie taps toelopende snijstrepen op het doelwit.
- [ ] **Bite** — twee sluitende bogen met tanden rondom het doelwit.
- [ ] **Ember** — drie kleine vuurprojectielen, korte trails en vonken bij de inslag.
- [ ] **Water Gun** — een blauwe stroom met lichte kern en een korte watersplash.
- [ ] **Thunder Shock** — vertakte gele elektriciteit met lichte kern en impactaccenten.

## Offline visuele review

Vanuit de game-controlmap in de toegewezen taskslot:

```sh
ops/worktrees/slot-env slot-b -- godot --path .worktrees/slot-b/frontend --script res://tests/battle_dialogue_preview.gd -- --moves
```

Kies een move en **Afspelen**. De knoppen ondersteunen raak/mis/geblokkeerd,
rechter aanvaller, pauze en annuleren. Via de Pokémon-keuze kun je de linker
Pokémon vervangen; via de arena-keuze en **Load preview** kun je van arena wisselen.
De camera blijft vrij draaibaar. De getoonde combinaties zijn een visuele test,
geen controle van learnsets. Er wordt geen serverbattle aangemaakt en er worden
geen instellingen opgeslagen. De preview toont de damage-reactie maar wijzigt geen HP.

`--moves --smoke-moves` controleert de zes moves in beide richtingen, miss/block,
pauze en annuleren met echte modellen in de PvP-arena. Met `POKEAETHER_STAGE_OUTPUT`
worden screenshots bij de inslag opgeslagen.

## Timing, geluid en uitkomsten

`move_effect_3d.gd` tekent uitsluitend native, schaduwloze arena-meshes. Posities
volgen de huidige modelbounds of de zichtbare Substitute-doll. Krassen/kaken en
inslagaccenten gebruiken de actuele camerabasis; projectielen en stralen volgen
wereldcoördinaten. Tijdelijke meshes worden niet naar de irradiancepass gekopieerd.
Er worden geen 2D-spritesheets geladen en geen camerabewegingen toegevoegd.

De zes specifieke bestaande 2D-movesamples blijven behouden. Contactgeluiden
spelen bij het contactmoment, vuur/water/elektriciteit bij het lanceren. Bronvolume
en pitch blijven behouden. Audiostaarten mogen natuurlijk uitspelen zonder de
volgende gebeurtenis op te houden; annuleren stopt ze wel. Missers gebruiken dezelfde
move-sample, maar zonder damage-geluid of succesvolle impactburst.

Model, VFX en audiocues delen de native animatieklok. De bestaande Pikachu/Tackle
pilot blijft gelden. Andere model/move-combinaties beginnen met een expliciete
**voorlopige choreografie op 45% van de clip**, geen individueel pose-gereviewd
raakframe. De volledige aanvalsclip speelt af: langere clips worden voor deze zes
moves versneld tot maximaal 1,25 seconde op normale replaysnelheid. Replaysnelheid
en pauze blijven afzonderlijk werken. Modelgebonden afwijkingen kunnen tijdens de
visuele review een preciezer anker of raakframe krijgen; de huidige mondpositie is
uit modelbounds afgeleid, niet aan een mondbot gekoppeld. Ontbreekt ook na de bestaande
clipfallback een geschikte aanvalsclip, dan blijft de bestaande model-only route gelden.

Een succesvolle impactburst wordt alleen toegestaan wanneer de geordende events
een directe hit op dit doel of een Substitute-hit bevestigen. Miss verplaatst het
visuele doel naast de Pokémon. Protect, immunity en fail krijgen geen succesvolle
impactburst; hun bestaande eventpresentatie blijft verantwoordelijk voor de reactie.
De bestaande impactbrug geeft alleen een enkele directe HP-hit vroeg vrij.
Multi-hit/spread en andere complexe events behouden de volledige geordende route;
de VFX passen zelf nooit schade, statussen of battle-uitkomsten toe.

De arena bewaakt zichtbaarheid en actorvervanging. Annuleren, fallback en teardown
stoppen effecten en hun geluiden. De echte 2D-fallback blijft de originele catalogus
gebruiken; moves buiten deze zes blijven zonder move-VFX en move-audio in 3D.

## Gerichte verificatie

- `battle_move_effects_3d_check.tscn`: zes moves, vier teamslots, geometrie,
  bestaande soundresources en cueposities, impact/herstel, uitkomstselectie,
  target replacement, miss-callback, ontbrekende audio, ontbrekende/verborgen
  targets, animaties uit en annuleren.
- `battle_move_presentation_routes_check.tscn`: stille overige moves, algemene
  effectaudio, annulering en echte 2D-fallback.
- `battle_3d_impact_pacing_check.tscn`: bestaande pilots, geordende HP-reacties,
  gem-before-attack, herstel en faintgedrag.
- De echte-modelpreview controleert de visuele route, beide richtingen en pauze.

Deze tests vervangen de bovenstaande zes visuele goedkeuringen niet. Niet ieder
Pokémon-model, iedere clip of ieder mondanker is daarmee individueel gereviewd.
