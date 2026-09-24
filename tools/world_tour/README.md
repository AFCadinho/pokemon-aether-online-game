# Herhaalbare wereldtour voor het inlogscherm

De camera filmt de echte gegenereerde kaartlagen met Godot, zonder speler, NPC's,
naamlabels of interface. Tile-animaties blijven behouden. Dit is een decoropname;
gameplay, quests en weerscripts van de volledige mapscène worden niet geladen.
De opnameviewport is gescheiden van eventuele autoload-interface van het project.
Er is geen login of draaiende backend nodig.

## Opnemen

Voer dit uit vanuit de frontend van een toegewezen werkslot, na de normale
`prepare-task`/`bootstrap-slot`. Godot, FFmpeg (libtheora en libx264) en een
grafische sessie moeten beschikbaar zijn. `--headless` rendert geen bruikbare
video. Het script roept Godot zelf via `ops/worktrees/slot-env` aan.

```sh
python tools/world_tour/record.py --check
python tools/world_tour/record.py --preview --output ../.tmp/tour-preview-02
python tools/world_tour/record.py --install --output ../.tmp/tour-02
```

Elke uitvoermap moet nieuw zijn: vorige opnamen worden bewaard. `--preview`
maakt één PNG halverwege elke scène om het camerakader snel te beoordelen.
Een volledige opname levert `preview.mp4`, `login_background.ogv`, alle PNG-frames,
de gebruikte `route.json` en `capture.log` op. Zonder `--install` blijft de
bestaande loginvideo staan. Met `--install` wordt alleen de video in het eigen
slot vervangen, nadat opname en encoding zijn geslaagd. Review, commit en merge
naar development volgen de normale workflow; dit publiceert niets.

De standaardtour bevat alle 16 geselecteerde buitenkaartdecors uit de
wereldcatalogus plus Mt. Moon 1F en duurt 1 minuut en 8 seconden, op 1280×720
bij 30 fps. Dit omvat steden, routes, Viridian Forest en de buitengebieden van
Aether Clash. Andere gebouwen, indoor-doorgangen en grotten zijn uitgesloten,
net als het tijdelijke open-field-decor van Route 5 en Route 9. De duel-preview
wordt niet dubbel gefilmd; `areas` vermeldt alle vertegenwoordigde locaties. Zie
[COVERAGE.md](COVERAGE.md). Theora-kwaliteit 6 en keyframeafstand 64 houden de loginvideo scherp met een compacte bestandsgrootte.
Het bestaande inlogscherm speelt `assets/video/login_background.ogv` af en start
deze opnieuw aan het einde. De laatste scène mengt al terug naar de eerste;
de camerabeweging loopt daarbij door over de lusgrens. Er is geen audio.

## Nieuwe mappen of een andere route

Bewerk `route.json`, of gebruik `--route pad/naar/andere-route.json`.

De standaardroute gebruikt `coverage: "all_outdoor_maps"`. Bij een nieuwe buitenmap
controleert de tool via `generated/world_access_catalog.json` ook geneste
scène-templates. Ontbrekende buitendecors en ongewenste interieurs blokkeren de
opname. Voeg bij een nieuw buitendecor een shot toe en werk `areas` bij. `python tools/world_tour/catalog.py` toont de actuele
koppeling. Laat `coverage` weg voor een bewust geselecteerde deelroute. Locaties
zonder mapscène staan apart in `unbuilt_areas`; ze zijn nog niet te filmen.
Bewuste uitzonderingen staan met reden in `excluded_visuals`. De uitsluiting
van open field geldt alleen voor dat tijdelijke decor: zodra Route 5 of Route 9
een eigen decor krijgt, meldt de controle dat de nieuwe map moet worden toegevoegd.

- `shots`: de gewenste volgorde; minimaal twee scènes.
- `scene`: de bijbehorende `res://generated/tiled_visuals/.../*.visual.tscn`.
  Gebruik de Visuals-resource uit de mapscène, niet de gameplayscène zelf.
- `from` en `to`: cameramiddelpunten in wereldpixels `[x, y]`.
- `view_width`: hoeveel wereldpixels horizontaal in beeld komen. Groter = verder
  uitgezoomd. De bijbehorende hoogte volgt de videoverhouding.
- `shot_seconds`: tijd tussen twee overgangen; de totale lusduur is dit getal
  maal het aantal scènes. Moet een heel aantal videoframes opleveren.
- `transition_seconds`: duur van de zachte overgang, korter dan een scène.
- `width`, `height`, `fps`: uitvoerformaat; afmetingen moeten even zijn.

Houd de camera inclusief zijn halve beeldbreedte/-hoogte binnen het getekende
mapgebied. De tool klemt de camera niet automatisch: zo blijven gekozen routes
voorspelbaar. Tijdens een overgang is de volgende scène al zichtbaar en begint
haar beweging. Daarom bestrijkt een camerabeweging `shot_seconds +
transition_seconds`. De eerste filmframe zit al een overgangsduur in de eerste
beweging, aansluitend op de laatste filmframe.

Genereer/importeer nieuwe kaartassets eerst via de normale mapworkflow. Bekijk
de previewbeelden, daarna de volledige MP4 inclusief overgangen en lusgrens.
Controleer ook het inlogscherm: het formulier en de bestaande donkere laag
staan pas bij afspelen over de schone opname heen.

## Gerichte controles

```sh
python -m unittest discover -s tools/world_tour -p 'test_*.py'
python tools/world_tour/record.py --check
```

De tool stopt bij ontbrekende kaarten, ongeldige routes, onvolledige opnamen,
scriptfouten of mislukte encoding. Ruwe frames kunnen veel schijfruimte gebruiken;
bewaar alleen de gewenste opnamen na review. Werkslotcaches en userdata worden
niet gekopieerd of gedeeld.
