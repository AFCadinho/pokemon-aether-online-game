# Lokale battlekwalificatie van 14 gereconstrueerde vormen

Deze stap volgt op de goedgekeurde kleur-/zichtbaarheidspreview (“zien er goed
uit”) en de goedgekeurde slaapreparaties (“is goed”). De selectie bestaat uit
Burmy Sandy/Trash, Wormadam Sandy/Trash, Cherrim Sunshine, zeven Minior-vormen
(Blue, Green, Indigo, Meteor, Orange, Violet, Yellow) en Cramorant Gorging/Gulping,
steeds normaal en shiny. De toelating is uitsluitend lokaal voor de volgende
modelrelease. De actieve release-index, R2 en bestaande pakketten blijven staan.
Na toelating zijn 208 van de oorspronkelijke 229 vormen lokaal hersteld en
blijven 21 vormen open.

## Afbakening van de reconstructie

De eerdere preview- en slaaprapporten blijven onveranderd. De nieuwe kwalificatie
bindt de exacte 28 goedgekeurde scènes aan de gemeten scènes en modelpakketten.
Burmy/Wormadam/Cherrim behouden de visueel geaccepteerde gereconstrueerde
shiny-kleuren. Minior behoudt de geaccepteerde shader en statische zichtbaarheid.
Cramorant houdt de juiste prooi en de eerder beoordeelde samengestelde slaappose.
Er wordt geen volledige gelijkheid aan de oorspronkelijke game-engine geclaimd.
Dynamische vormwissels en het wegschieten van Cramorants prooi zijn geen onderdeel
van deze kwalificatie.

Materialen zijn per exemplaar onafhankelijk; ongewijzigde textures worden in
normal/shiny-pakketten gedeeld. Bij Burmy en Wormadam worden de constante
oogtexture-wissels discreet uitgevoerd. De eerdere continue texturetracks
veroorzaakten bij de echte laadroute achtergebleven texture-resources bij
procesafsluiting. Een gerichte proef met discrete wissels verholp die fout.
Cramorants texturetracks bleven een afsluitfout geven, ook in een pakket met
volledig ingebedde textures. Deze twee vormen selecteren daarom hun oogstand
met zichtbaarheid: een extra ooginstantie deelt exact dezelfde mesh, skin en
skeletkoppeling, en gebruikt de goedgekeurde gesloten-oogtextures. Er staat
altijd precies één ooginstantie aan. Alle oorspronkelijke textures, UVs en
filterinstellingen blijven intact. Naast de resource- en battlevergelijkingen
worden beide varianten direct pixelgewijs met de goedgekeurde preview vergeleken.

De nieuwe voorbereiding controleert dat elke omgezette texturetrack binnen de clip
één constante texture kiest. Een vergelijking van alle opgeslagen resources
staat uitsluitend deze update-modus en het materiaaleigenaarschap als wijziging
toe; voor Cramorant wordt daarnaast uitsluitend de bewezen equivalente
oogzichtbaarheidsselectie genormaliseerd. Geometrie, textures, broncurves en
oogselectie blijven gelijk.

Minior krijgt een vaste extra bodemafstand van 0,001 game-eenheid. De eerdere
60 Hz calibratie miste bij de onafhankelijke 120 Hz controle de minimumafstand
van 0,025 met ongeveer 0,00003. De oorspronkelijke positie wordt verder behouden.
De afgekeurde metingen en continue-texture-kandidaten blijven in dezelfde slotmap
bewaard voor vergelijking.

## Controle en bewijs

De lokale rapportage staat in
`tools/sprite_factory/remaining_fourteen_qualification.json`. Deze wordt pas
voltooid wanneer alle volgende controles slagen:

- Beide varianten, alle clips, beide arena's en zijden: plaatsingsmeting,
  minimaal 0,025 bodemafstand bij 120 Hz, camerakaders en HUD-proxy.
- Gecomprimeerde normal/shiny-pakketten: volledige resourcevergelijking,
  afhankelijkheden, integriteit, vrijgeven en pixelvergelijking in Mobile/Vulkan.
- De game-laadroute met lokale bestanden: team preview, voorbereiding vóór
  tonen, exacte normal/shiny-identiteit en wisselen zonder extra download.
- Echte BattleDisplay in Compatibility/OpenGL en Mobile/Vulkan: normal/shiny,
  normal/normal en shiny/shiny in beide arena's, alle acties op drie tijdstippen,
  onafhankelijke materialen/zichtbaarheid, faint en vervanging.
- De actieve materialen, textures en zichtbaarheid worden vergeleken met de
  goedgekeurde previews. De referentie krijgt dezelfde bestaande oppervlakte-
  sorteervolgorde als de game. Alleen het per-instance eigenaarschapsvlaggetje
  valt buiten die uiterlijkvergelijking; het wordt afzonderlijk gecontroleerd.
- Een extra laadcontrole gebruikt de uiteindelijke gamecatalogus. Regressietests
  bewaken gelijke game-/launchercatalogi en onveranderde eerdere toelatingen.

Dit zijn Linux-tests met Godot 4.6.2. Mobile is hier de Vulkan-renderer op de
Linux-machine; het is geen fysieke Android-test. Er zijn geen Windows- of
macOS-tests en geen downloadtests vanaf R2 uitgevoerd.

De 14 pakketten zijn samen 71.977.676 bytes (68,64 MiB). Er zijn 328
pixelidentieke pakket-/scènebeelden en nog 40 directe vergelijkingen tussen de
Cramorant-kandidaten en de goedgekeurde previews. De plaatsingscontrole omvat
768 beelden. De echte BattleDisplay levert 3.960 controles van uiterlijk en
3.960 controles van onafhankelijkheid, verdeeld over 168 gevechtsparen en
168 faint/vervangingen. Het zijn uitsluitend lokale, offline modeltests.

## Herhalen

Artifacts blijven in slot-c/frontend/.tmp/remaining-fourteen-battle-v1. De helper
`remaining_fourteen_battle.py` heeft de fasen `setup`, `prepare`, `battle`,
`delivery`, `ui` en voor Cramorant `preview-parity`, plus een selectie via `--only`. De helper gebruikt de behouden
bronpreviews in hetzelfde slot. Gebruik een toegewezen slot en stel
`POKEAETHER_SLOT=slot-c` in; alle Godot-processen lopen via `slot-env`.
`remaining_fourteen_admission.py admit` schrijft de lokale toelating;
`finalize` controleert die via de game. Geen helper uploadt of publiceert.
