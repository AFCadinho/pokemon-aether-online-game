# Performanceverbeteringen — 8 september 2026

Vervolg op [de gamebrede audit](game-performance-audit-2026-09-08.md).
Uitgevoerd in gepaard slot C, taak `game-performance-improvements`.
De vier implementatiefases zijn afzonderlijk getest, gecommit en samengevoegd
in lokale `development`. Geen promotie, push, release of productieonderzoek.
De volledige development-certificering is volgens de werkafspraken niet gestart.

## Doorgevoerde fases

| Fase | Bevindingen | Uitwerking |
| --- | --- | --- |
| 1 | F01, F02, F08 | Guildtextures vergelijken en delen; dezelfde idle-pose overslaan; verborgen appearance-animaties pauzeren; losstaande previewloaders met hun UI vrijgeven. Positieverwerking blijft actief. |
| 2 | F03, F04, F09, F16 | Spriteframes tussen loaders delen; transparante randen gericht scannen; dubbele bounds- en tintberekeningen verwijderen; caches begrenzen; identieke animatiebeelden naar hetzelfde bestaande bestand verwijzen; twee grote loginlogo-imports begrenzen op 2048 pixels. |
| 3 | F05–F07, F12–F13 | Presence indexeren per gebruiker/map; gelijktijdig verzenden met volgorde, deadline en wachtrijlimiet per ontvanger; overtollige client-appearancevelden verwijderen; packetverwerking over frames verdelen; HTTP-verbindingen hergebruiken; weeropvragingen naar binnenkomst en heartbeat verplaatsen. |
| 4 | F10–F11, F14–F15, F17 | SQL sluit reeds geplaatste Pokémon uit vóór payloads worden geladen; oorspronkelijke trainers en eigenaars in groepen laden; dex-vensters bij eerste gebruik bouwen; vaste HUD-layout alleen bij wijzigingen bijwerken; NPC-topologie indexeren; overworldweer koppelen aan de weerswitch en ongewijzigde viewportberekeningen overslaan. |

### Grenzen en behoud van gedrag

- Cachelimieten zijn aantallen resources, geen harde RAM/VRAM-limieten:
  64 guildtextures, 32 gedeelde spritesets, 32 sets per loader en 128 entries
  per appearance-cache. Nog zichtbare resources blijven geldig na cache-evictie.
- Originele animatiebestanden zijn behouden. Alleen byte-identieke verwijzingen
  zijn gedeeld; dit is geen claim dat de export al ontdubbeld of kleiner is.
- Presence-, chat- en PvP-streams verwerken elk maximaal 64 packets per frame,
  met een zacht budget van 2 ms per stream. Een begonnen packet wordt afgemaakt;
  resterende packets blijven in volgorde staan. Het is geen globaal 2 ms-budget
  voor de hele game en geen garantie tegen één duur snapshot.
- Langzame presence-ontvangers krijgen maximaal 32 wachtende sends. De
  send-deadline van 0,5 seconde omvat ook wachten op eerdere sends; sluiten
  heeft afzonderlijk een deadline. Overbelaste sockets sluiten met code 1013.
- HTTP-pools bewaren geen responsecookies van spelers. Autorisatieheaders en
  proxy-timeouts zijn per request; pools sluiten bij shutdown.
- De backfill/herstelstap blijft bestaan. Party-, mail-, guildbank-, retirement-
  en holderfilters blijven van kracht. Er is geen datamigratie uitgevoerd.
- De volledige PC-boxlijst bevat nog steeds volledige Pokémongegevens. Een
  compacter overzicht met ander frontendcontract is bewust niet ingevoerd.
- De NPC-index bewaart alleen relevante nodes. Posities, poortstatus en
  storyvoorwaarden worden bij iedere vraag opnieuw beoordeeld. Wijzigingen in
  de SceneTree maken de index ongeldig; off-tree gebruik blijft mogelijk.
- Eerste opening van een dex betaalt nu de opbouwkosten. De rest van de grote
  interface wordt nog bij startup opgebouwd. Dit is een gerichte vermindering,
  geen volledige herbouw van de UI-startup.
- Creator-weervoorbeelden behouden hun expliciete override; na sluiten geldt
  weer de spelersinstelling. De serverweerstatus zelf verandert niet.

## Lokale metingen

Zelfde headless CPU-probes als de audit, met synthetische gegevens. Dit zijn
functietijden, geen FPS-, GPU- of productie-latentiemetingen. OS- en resourcecaches
beïnvloeden vooral eerste loads. Een eerste functieaanroep is geen gegarandeerd
koude schijfmeting. Waarden zijn afgerond.

| Werk | Audit | Nameting |
| --- | ---: | ---: |
| Avatarupdate met guildembleem | 0,463 ms | 0,073 ms |
| Dezelfde idle-animatie bijwerken | 0,104 ms | 0,00038 ms |
| Complete standaard skin-tintset | circa 42 ms | 26,0 ms |
| Eerste Charizard-spriteset | 99,9 ms | 9,9 ms |
| Eerste Gyarados-spriteset | 83,3 ms | 8,9 ms |
| Eerste Pikachu-spriteset | 19,5 ms | 18,9 ms in laatste run; 2,4 ms in eerdere nameting |
| Cerulean-topologie, synthetische vrije bestemming | 0,094 ms | 0,0086 ms met warme index |
| Presence: 1.000 verbindingen, 10 op de map, p50 | 0,638 ms | 0,122 ms |

De laatste topology-probe meet ook het niet-geïndexeerde pad van de nieuwe code:
Cerulean circa 0,117 ms tegenover 0,0086 ms met index. De synthetische callbacks
doen geen echt story-/collisionwerk. Het voordeel betreft het overslaan van
subtrees; het zegt niet hoeveel een daadwerkelijke loopstap in totaal kost.

### Afweging bij ontvangerisolatie

| Totale verbindingen / op de map | Audit p50 | Nieuw p50 / p95 |
| --- | ---: | ---: |
| 10 / 10 | 0,035 ms | 0,125 / 0,136 ms |
| 100 / 10 | 0,089 ms | 0,122 / 0,136 ms |
| 1.000 / 10 | 0,638 ms | 0,122 / 0,139 ms |
| 100 / 100 | 0,108 ms | 0,737 / 0,764 ms |
| 500 / 500 | 0,446 ms | 3,394 / 3,853 ms |

Verbindingen op andere maps maken het bewegingspad niet meer evenredig duurder.
Maar gelijktijdig verzenden met locks/deadlines kost meer CPU dan de oude seriële
lus wanneer alle synthetische sockets onmiddellijk klaar zijn. Een overbodige
extra async-taak per send is na meting verwijderd. De resterende toename is een
expliciete afweging voor ontvangerisolatie en begrensde wachttijd.

De proef met één ontvanger die 50 ms wacht duurt als geheel nog circa 50 ms:
de broadcaster wacht op alle resultaten. Een aparte async-test bewijst dat een
gezonde ontvanger zijn bericht krijgt terwijl de trage ontvanger nog geblokkeerd
is. Dit is geen gemeten verbetering van de totale broadcasttijd. Op extreem
drukke maps blijft fan-out een schaalbaarheidsgrens; een echte belastingproef is
nodig vóór uitspraken over ondersteunde spelersaantallen.

## Gerichte verificatie

- Fase 1: avatar/resource-lifecycle, staffbadge, remote renderlayers, Surf-rendering,
  Surf-presence en Cyclizar-controles geslaagd.
- Fase 2: appearance-kleuren, spritecache, Pokédex-schaal, avatar-lifecycle,
  battle-anchors en custom projectiles geslaagd. Byte-identiteit van alle
  gewijzigde animatieverwijzingen gecontroleerd. Slot-import afgerond.
- Fase 3: 44 gateway-presencetests; 49 orchestrator-clienttests plus 2 subtests;
  gerichte gateway-proxy/pooltests geslaagd. Frontend packetbudget via lokale
  loopback-WebSocket, roster en Surf-presence geslaagd.
- De bestaande PvP-streamcontrole haalt zijn assertions, maar meldt bij afsluiten
  nog ObjectDB/resources die in gebruik zijn. Deze afsluitmelding is niet als
  een schone resourcecheck meegeteld.
- Fase 4: 71 opslagtests met uitsluitend een tijdelijke SQLite-geheugendatabase.
  Nieuwe test: twintig reeds boxed Pokémon worden niet gehydrateerd tijdens
  herstel van één ontbrekende Pokémon. Nieuwe test: tien verschillende
  oorspronkelijke trainers vragen maximaal twee users-queries.
- Fase 4 frontend: overworldweer, weerswitch/camera, dynamische blockerindex,
  routepoorten, dex-opbouw/layout, dex-localisatie, Pokédex-layout en -spriteschaal,
  en overlay-z-index geslaagd. Geen script-errors in de definitieve runs.
- Verouderde testfixtures bijgewerkt: opslagfixture miste inmiddels gebruikte
  tabellen/kolom; gedeeltelijke dex-fixture riep volledige chat/buff-refresh aan;
  een oude tekstassertie verwachtte niet meer gebruikte kwartstapschaling.
  Schaal/fit blijft door de bestaande runtime-spritetest gedekt.
- Definitieve frontend-CPU-probe: exit 0, geen script- of resource-errors.
  UID-fallbackwaarschuwingen bij bestaande assets blijven zichtbaar.

## Fase 5: nog uit te voeren praktijkprofiling

Windows release-exports op snelle en zwakkere hardware zijn hier niet beschikbaar.
De GPU-kosten, werkelijke framepercentielen, langetermijn-RAM/VRAM en gedragingen
onder echte netwerkbelasting zijn daarom nog niet afgetekend. Bestaande lokale
CPU-probes vervangen deze fase niet.

Gebruik voor voor/na dezelfde machine, resolutie, renderer, FPS-limiet, account-
en mapsituatie. Leg exacte buildcommits vast en scheid eerste login van herhaling.
Meet per scenario driemaal 60 seconden en doe daarnaast een sessie van 20 minuten
met herhaalde mapwissels, battles, dex/PC-openingen en relogs.

| Scenario | Te vergelijken |
| --- | --- |
| Inloggen in Cerulean en Pewter | Eerste 10 seconden en de periode daarna apart |
| Drukke Cerulean, 10/30/60 zichtbare avatars | Stilstaan, bewegen, guildemblemen, Surf/mounts; vervolgens spelers verbergen |
| Helder weer, regen, sneeuw | Weerswitch tijdens spelen; camerabeweging en vensterresize |
| Eerste battle en langere battle | Eerste sprites, wissels, effecten, framespikes |
| PC met grote/geruilde collectie | Eerste opening, boxwissels, queryaantal, responsbytes en serverlatentie |
| Item Dex/Pokédex | Eerste opening, heropenen, itemlink vanuit Pokédex, zoeken en locale wisselen |
| 20 minuten herhaald gebruik | RAM/VRAM-trend en herstel na sluiten, caches, reconnect |

Leg frame-p50/p95/p99 vast, het aantal frames boven 16,7/33,3/50 ms, RAM/VRAM,
draw calls, serverrespons-p50/p95/p99 en eventuele reconnects. Meet serverfan-out
apart met representatieve vertraagde ontvangers in een geïsoleerde testomgeving.
Geen productiebelastingstest zonder afzonderlijke autorisatie.

## Reproduceren en commits

Vanuit de workspace, zolang slot C voor deze taak is gereserveerd:

```sh
ops/worktrees/slot-env slot-c -- godot --headless --path .worktrees/slot-c/frontend --script res://tools/performance/game_audit.gd
python3 .worktrees/slot-c/backend/ops/performance/presence_audit.py
```

De probes starten geen echte world of backend. Alleen synthetische topologie gaat
in de SceneTree; echte scenes blijven erbuiten. Ruwe lokale logs staan onder
`/tmp/game-perf-final-benchmark.log`, `/tmp/perf-presence-final-benchmark.log` en
`/tmp/perf-phase*`; bovenstaande cijfers blijven in dit document bewaard.

| Fase | Frontendcommit | Backendcommit |
| --- | --- | --- |
| 1 | `4203d600f` | — |
| Teardown-follow-up | `510e56001` | — |
| 2 | `aecab6dd2` | — |
| 3 | `60ccad286` | `405658a` |
| 4 + send-overheadfollow-up | `34a41e9d8` | `98bae69` |

Backendmerge `4342131` bewaart de tussentijdse developmentwijzigingen en beide
changelogregels. Slot C blijft beschikbaar voor gameplay- en visuele feedback.
