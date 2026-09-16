# Misty-mapmodule — proefexport 15 september 2026

De daaropvolgende technische core-plus-moduleproef is vastgelegd in
`browser-misty-core-integration.md`. De metingen hieronder blijven de resultaten
van de oorspronkelijke visual-only proef, niet van actieve gameplay.

## Uitkomst

Een afzonderlijke Misty-module is haalbaar qua download. De speelgrens is niet
gewijzigd; dit is een experiment, geen vrijgegeven browsercontent of releasegate.
De huidige core-export, Aether Clash-module en productie blijven ongewijzigd.

| Meting | Resultaat |
| --- | ---: |
| PCK | 20.811.552 bytes / **19,85 MiB** |
| Gzip van hetzelfde PCK | 14.519.462 bytes / **13,85 MiB** |
| Budget voor dit experiment | 32 MiB |
| Geplande maps aanwezig | 16/16 |
| Mapvisuals vanuit werkelijk PCK geladen | 12/12 |
| Geïnspecteerde portable textures | 81, inclusief gedeeld Pokémon Center |
| Gebieden buiten geplande scope in PCK | Geen canonieke map buiten de 16 IDs |
| Aether Clash-maps in PCK | Geen |
| Muziek in PCK | Geen |

SHA-256 van het gemeten pakket:
`78d85951b124c2bf300cff45945385a1a2d03bb99f8be7bb69c6c9967f648068`.
De bytes zijn slot-eigen buildartefacten en worden niet gecommit of gesynchroniseerd.

## Chromium en geheugen: bewijsgrenzen

Geïsoleerde WebGL 2-probe in headless Chromium, 1280×720, met software-rendering.
Geen accounts, backendverkeer of externe requests. Er is een echte browserdownload,
PCK-mount en rendering van de 12 generated mapvisuals uitgevoerd, één na één.
Dit is **geen** complete map/gameplaytest: NPC-scripts, spelers, bots, volledige
interieurtemplates, muziek en battles zijn niet als spel gestart.

De lokale static server stuurde de module ongecomprimeerd:
20.811.852 transferbytes inclusief circa 300 bytes HTTP-overhead. De laatste
loopback-download duurde circa 154 ms; dat voorspelt geen internetlaadtijd.
13,85 MiB gzip is een lokaal berekende transfermogelijkheid, geen reeds
geconfigureerde hostingcompressie. Brotli is niet gemeten.

Godots `RENDER_TEXTURE_MEM_USED` rapporteerde tijdens rendering onder andere:

| Visual | Getelde texture-memory MiB |
| --- | ---: |
| Route 3 / Route 4 | 141,00 |
| Mt. Moon 1F / B1F / B2F | 148,80 / 152,35 / 14,86 |
| Cerulean City / Route 24 / Route 25 | 144,55 |
| Cerulean Gym / bike shop | **209,03** |
| Huistemplate / Bill’s visual | 71,55 |

Dit is de engine-teller van de **probe**, geen volledige GPU-driver- of
procesgeheugenmeting en geen gegarandeerd geïsoleerde texturekost per map.
De inspectie maakt resources aan en loopt maps achtereenvolgens door; GPU-
vrijgave en rendererallocaties kunnen de teller beïnvloeden. Het kan niet als
incrementele kost boven op de normale game worden opgeteld.

De som van theoretische RGBA-pixels van alle 81 pakkettextures is 554,03 MiB;
dat is geen gelijktijdig resident gebruik. Het reguliere spel hoort slechts de
benodigde mapresources te laden, niet alle maps tegelijk.

Godots algemene static-memoryteller gaf op Web nul en is daar onbruikbaar.
Chromium CDP gaf ongeveer 8,52 MiB gebruikte JS-heap / 10,11 MiB JS-heapcapaciteit.
Die cijfers omvatten **niet** het volledige Wasm-, GPU- en browserprocesgeheugen.
De native headless visualprobe piekte rond 211,8 MiB static-memory; ook dat is
geen gemeten browser-RAM. Een totale browser-RAM-grens is dus nog niet bewezen.

De geïsoleerde probe heeft geen game-UID-registry. De twaalf visualscenes geven
elk één expliciete UID-waarschuwing en laden vervolgens succesvol via het
resourcepad. Waarschuwingen en hun stackregel blijven in `browser-report.json`
staan; alle andere browsererrors en mislukte requests laten de test falen.
Bij integratie moet de echte core-plus-moduleloader opnieuw op UID/remaps worden
getest; deze proef bewijst niet dat de normale game dezelfde waarschuwingen geeft.

## Aanbevolen volgende fase

Behoud Lobby in de core en Aether Clash in zijn bestaande aparte module.
Gebruik voor Route 3 t/m Misty één afzonderlijke mapmodule. Het bestaande
312 MiB-corebudget hoeft hiervoor niet te worden verhoogd.

Vóór inhoudelijke vrijgave:

1. Test core + module in een geïsoleerde browsergame, inclusief alle 16 complete
   scenes, dynamische NPC-assets, scripts en gedeelde resources. Het proefpakket
   bevat gedeelde dependencies; mount zonder vervanging van core-assets.
2. Meet geheugen vóór/na laden en na herhaalde buitenmap ↔ interieurwissels,
   relog en battle. Controleer dat oude scenes/textures en downloadbuffers
   vrijkomen; onderzoek de hoge Gym/bike-shop-teller vóór een geheugenbelofte.
3. Test een lagere geheugenklasse en netwerkvertraging. Bepaal dan pas concrete
   runtimegrenzen, retries en eventuele verdere deduplicatie.
4. Borg audio afzonderlijk: Mt. Moon/Cerulean zijn al aanwezig in de bestaande
   raw browser-audio-output, maar niet in dit PCK. Verifieer de werkelijk
   gebruikte afspeelpaden zonder onnodige dubbele muziekdownload.
5. Daarna pas canonieke mapallowlist, Cerulean-Aethernet en doelmaploader koppelen
   en de Brock → Misty-storyslice testen. Route 5/9/Cerulean Cave blijven dicht.

## Herhalen in slot C

Vanuit de workspace-root:

```sh
ops/worktrees/slot-env slot-c -- python .worktrees/slot-c/frontend/tools/build_web_misty_trial.py
```

De builder exporteert alleen preset `Web Misty Maps Trial`, controleert het
werkelijke PCK in een bare native probe en genereert een kleine browserprobe.
Geen wijziging aan `builds/web/modules/manifest.json` of de live preview.
De gepaarde backendcatalogus is een expliciete lokale invoer.

Daarna vanuit de frontend-slotmap, in twee terminals:

```sh
python -m http.server 8063 --bind 127.0.0.1 --directory builds/web-misty-trial
node tests/web_misty_asset_probe.cjs
```

Gerichte checks:

- `python -m unittest discover -s tests -p test_web_misty_trial.py`: 5 PASS;
  ontbrekende maps, boundary-leaks, andere ongeplande maps en Aether Clash-leaks.
- Native pakketprobe: PASS, 16 geselecteerde maps aanwezig / 12 visuals geladen.
- Chromium `web_misty_asset_probe.cjs`: PASS, 12 visuals, geen externe of
  mislukte requests en geen errors behalve afzonderlijk bewaarde UID-warnings.

Alle receipts, exportlogs en screenshot staan alleen in
`builds/web-misty-trial/` van de taakslot. Dit is geen volledige paired gate,
browserplaythrough, promotie, push, publicatie of deployment.
