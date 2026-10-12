# Eerste 14 van de resterende 35: lokale previews

Er zijn 28 zelfstandige Godot-previews gemaakt voor vijf kleurgevallen en negen
zichtbaarheidsgevallen, telkens normaal en shiny. **Geen nieuwe vorm is
toegelaten. Er blijven formeel 35 vormen open.** De overige 21 zijn in deze
stap niet aangepast. Catalogus, launcher, bestaande kwalificaties, release-index
en R2 zijn ongewijzigd.

## Bekijken

De lokale kijkpagina staat in het behouden slot-c:

`.tmp/remaining-colour-visibility-v1/index.html`

De pagina bevat per vorm twee video's met een rondgang en alle beschikbare
clips, afzonderlijke slaapposes en voor de vijf kleurgevallen een bestaande
shiny-HOME-referentie. De lossless PNG-opnamen blijven naast de video's staan.
De video's zijn alleen kijkmateriaal en worden niet als gametextures gebruikt.

De twee contactbladen staan in dezelfde map:

- `colour-review-v2-contact.png`: Burmy Sandy/Trash, Wormadam Sandy/Trash,
  Cherrim Sunshine;
- `visibility-review-v2-contact.png`: Minior Blue/Green/Indigo/Meteor/Orange/
  Violet/Yellow en Cramorant Gorging/Gulping.

## Wat is hersteld en wat blijft open?

| Familie | Uitgevoerde proef | Resterend werk vóór toelating |
| --- | --- | --- |
| Burmy, Wormadam (4 vormen) | Eigen geometrie en bewegingen; oorspronkelijke normale materiaalgraph gebakken; alleen de donkere lichaamslaag krijgt een voorgesteld blauwgrijs shiny-palet. Mantel en ogen behouden hun oorspronkelijke palet. | Shiny-kleur beoordelen. Slaapogen en overige oogexpressies ontbreken in deze bronroute: de slaappose houdt de ogen open. |
| Cherrim Sunshine (1) | Normale bronmaterialen en eigen bewegingen; afzonderlijke shiny-kleurvoorstellen voor bloembladen, kop en bollen. Oogmaterialen en groene bladeren blijven behouden. Slapen sluit de geometrische oogleden. | Kleuren en volledige bewegingen visueel beoordelen; daarna battlekwalificatie. |
| Minior (7) | Kernvormen verbergen schil en losse fragmenten; Meteor houdt de schil, kern en punten, maar verbergt kernogen en mond. Fragmenten blijven verborgen. Native paletselecties bepalen de normale en shiny-kleuren. | Beeldgoedkeuring van alle toestanden. De zichtbaarheid is een voorgestelde vaste vormtoestand per clip, geen teruggevonden broncurve. Dynamische vormwissel en oorspronkelijke materiaalanimatie zijn niet bewezen. |
| Cramorant (2) | Gorging toont alleen Pikachu; Gulping alleen Arrokuda. Eigen aanvallen en native normale/shiny-paletten blijven behouden. | **Slaappose afgekeurd:** de eerder bewezen identieke skeletonbinding bewijst geen correcte houding mét prooi. De prooi steekt bij de basis-slaappose door het lijf. Ook oogexpressies ontbreken. Een eigen aangepaste slaappose en ogen zijn nodig. |

De vijf shiny-paletten zijn **visuele reconstructies**, gebaseerd op de reeds
aanwezige sprites en HOME-afbeeldingen. Er is geen oorspronkelijke shiny-tabel
teruggevonden. De expliciete kleuren staan in
`tools/sprite_factory/remaining_colour_recipe.json`. Bronbestanden, referenties,
materiaallagen en bakecode zijn met hashes vastgelegd.

Bij Minior onthulde het verbergen van de schil een tweede probleem: de eerdere
diagnostische omzetter verloor de lichtgevende lagen en de laaggebonden
ruwheid/metaalwaarden. De nieuwe, uitsluitend lokale shader leest het bronpalet
in lineaire kleurruimte en bemonstert albedo, laagmasker, normal, AO, ruwheid en
metaal elk op hun oorspronkelijke resolutie. Zo wordt bijvoorbeeld een
512-pixel albedo niet teruggebracht naar het 256-pixel masker. Deze vertaling
bewijst geen identieke materiaalrespons aan de oorspronkelijke game-engine;
onder meer de native emissiemengoptie van het oog blijft onbewezen.

Een extra Meteor-proef zonder kern is verworpen: daarmee verdwijnen ook de
punten. De definitieve preview houdt daarom de kern achter de schil. De
oorspronkelijke schilmesh en details zijn behouden, ook waar ze van de oudere
sprite-referentie verschillen.

## Uitgevoerde controles

Op Linux, Godot 4.6.2, Compatibility/OpenGL:

- 28 modellen laden, renderen en serialiseren als zelfstandige `.scn`;
- 220 clips, 660 begin/midden/eind-posemetingen en een omgekeerde clipvolgorde
  zonder technische fouten;
- 6.340 werkelijk gerenderde videoframes;
- 60.746 controles van zichtbaarheid tegen de expliciete vormvoorstellen;
- geometrie-, UV-, skin- en bewegingspariteit tussen oorspronkelijke export en
  de materiaalvarianten; bij de bestaande legacy-route wordt uitsluitend de
  verklaarde naamsnormalisatie teruggedraaid voor die vergelijking;
- hashes van bronnen, GLB's, native scènes, brontexturen, rapporten en video's;
- behoud van texture-resoluties in de Minior-shader en gebruik van de maximale
  bronresolutie per materiaal bij de Blender-bakes.

Deze technische controles keuren de genoemde visuele problemen niet goed.
Er zijn nog geen BattleDisplay-, plaatsings-, gedeeld-pakket- of downloadtests
voor deze voorstellen gedaan. Mobile/Vulkan, andere besturingssystemen en
fysieke telefoons zijn in deze stap niet getest.

`tools/sprite_factory/remaining_forms_preview_result.json` is een
**previewrapport**, geen kwalificatiebewijs. Alle goedkeuringsvelden staan
expliciet op `false`. Historische receipts zijn niet herschreven.

## Herhalen

Gebruik een toegewezen slot met de reeds aanwezige bronarchieven en eerdere
exports. De helpers schrijven uitsluitend naar de nieuwe previewmap; ze
publiceren niets. Blender draait zonder netwerk met expliciete
bestandstoegang. Alleen de Godot-processen gebruiken `slot-env`:

```sh
POKEAETHER_SLOT=slot-c python tools/sprite_factory/remaining_colour_preview.py
POKEAETHER_SLOT=slot-c python tools/sprite_factory/remaining_visibility_preview.py
```

De kleurstage staat onder `colour-v2/colour-stage.json`, de zichtbaarheidsstage
onder `visibility-stage.json`. Gebruik een autoload-vrij diagnostisch project
met symlinks naar `tools`, `scripts`, `resources` en `data` uit hetzelfde slot,
en zijn eigen importcache. Voer `remaining_forms_preview_build.gd` uit met de
absolute stage- en een verse reviewmap als twee argumenten na `--`.

Voer vervolgens `remaining_forms_preview_review.gd` uit met
`POKEAETHER_PHASE5_REVIEW` op die reviewmap, via `slot-env`, met een echt
renderdisplay. De helper weigert een voltooid reviewrapport te overschrijven.
`remaining_forms_preview_result.py` controleert de twee v2-rapporten, maakt de
video's met ffmpeg en schrijft kijkpagina en previewrapport.

## Vervolg

1. De vier Burmy/Wormadam-oogsets en beide Cramorant-slaapposes/oogsets apart
   reconstrueren en opnieuw renderen. Vooral Cramorant vereist meer dan een
   materiaalwijziging.
2. De kleurvoorstellen en Minior-vormtoestanden visueel laten beoordelen.
3. Alleen goedgekeurde kandidaten door de bestaande battle-, pakket- en
   toelatingsroute voeren. Pas daarna zijn ze gereed voor een modelrelease.
