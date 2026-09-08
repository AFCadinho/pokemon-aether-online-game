# Performance-analyse van PokeAether — 8 september 2026

De grootste aangetroffen risico's zitten in het voor het eerst verwerken van sprites,
herhaald werk voor andere spelers, de schaalbaarheid van world presence en het
vasthouden van spritegeheugen. De eerdere Cerulean-correcties zijn aanwezig; de
hieronder beschreven collision-traversal is een ander codepad dan de reeds gecachete
collisionlaag-lookup.

## Bereik en betrouwbaarheid

- Frontend onderzocht op `dc5dc0e2fe78f3785e3952ce9e1578c2877bfe4a`.
- Backend onderzocht op `40041519a5fb15c3c7656b5142808dce6bd86b6a`.
- Onderzocht: framecallbacks, speler/NPC-beweging, avatars, mapovergangen,
  weer, interface, battles en sprites, assets/caches, realtime sockets,
  gateway/upstreamverkeer, PC/collecties, ORM-laadgedrag, AI-workerbegrenzing
  en bestaande cleanup/pooling.
- Metingen: Linux, AMD Ryzen 7 5800H, Godot 4.6.2 headless. Geen GPU-rendering,
  echte spelersverbindingen, accountdata of productiebelasting gebruikt.
- **Gemeten** betekent een lokale geïsoleerde proef met echte functies en
  synthetische invoer. **Codebevinding** betekent dat het uitvoerpad is aangetoond,
  maar de impact in een volledige spelsessie nog niet is gemeten.
- Dit is een brede broncode-audit met gerichte CPU-metingen. Het is geen volledige
  live-profielopname, capaciteitstest of garantie dat alle knelpunten gevonden zijn.
  De getallen voorspellen geen FPS of maximale spelerscapaciteit op andere machines.

## Geprioriteerde bevindingen

P1: eerst aanpakken vanwege gemeten pieken, terugkerende kosten of schaalrisico.
P2: daarna gericht verbeteren of eerst de omvang in een spelsessie meten.

| ID | Prioriteit | Zwakke plek | Verwacht zichtbaar effect | Bewijs |
| --- | --- | --- | --- | --- |
| F01 | P1 | Guildlogo wordt bij iedere avatarupdate opnieuw gegenereerd | Haperingen in groepen met guildspelers | Gemeten |
| F02 | P1 | Avataranimatie draait ook bij stilstaande/verborgen spelers | Hogere CPU-kosten in drukke maps | Gemeten functie; codepad bevestigd |
| F03 | P1 | Eerste Pokémon-spriteweergave verwerkt pixels synchroon | Korte pauze bij battle, wissel, Pokédex of summary | Gemeten |
| F04 | P1 | Nieuwe kleurvarianten worden synchroon opgebouwd | Piek bij nieuwe outfits/huidskleuren | Gemeten |
| F05 | P1 | World presence scant alle verbindingen per spelerupdate | Toenemende serververtraging bij groei | Gemeten met synthetische sockets |
| F06 | P1 | Verzending naar spelers gebeurt achter elkaar | Trage ontvanger vertraagt latere ontvangers van die broadcast | Geïsoleerd aangetoond |
| F07 | P1 | Complete presence-pakketten; ontvangst zonder frametijdsbudget | Netwerkdruk en lange frames bij updatepieken | Codebevinding |
| F08 | P1 | Twee losstaande UI-sprite-loaders worden niet vrijgegeven | Geheugen kan na interfacevervanging blijven hangen | Lifetime-proef + codebevinding |
| F09 | P2 | Geen begrensde levensduur voor appearance-caches | Geheugengroei bij veel unieke uiterlijkvarianten | Codebevinding |
| F10 | P2 | PC-box lezen controleert volledige collectie | Tragere PC bij grote verzamelingen | Codebevinding |
| F11 | P2 | Mogelijke extra ORM-queries voor oorspronkelijke trainers | Extra databasewerk bij geruilde Pokémon | Codebevinding; querytelling nodig |
| F12 | P2 | Nieuwe HTTP-client per request in meerdere servicepaden | Extra verbindingsopbouw en CPU-werk | Codebevinding |
| F13 | P2 | Weather-override ophalen zit in presence-verwerking | Periodieke vertraging van volgende updates op dezelfde socket | Codebevinding |
| F14 | P2 | Grote UI-opbouw en terugkerende layoutberekeningen | Zwaardere start en onnodig werk tijdens spelen | Codebevinding; losse scene-load gemeten |
| F15 | P2 | Character-collision doorloopt complete NPC-subtrees | Extra werk per stap in bevolkte maps | Topologieproef, geen gameplaytiming |
| F16 | P2 | Grote en gedupliceerde afbeeldingen | Meer geheugen/assetwerk dan nodig | Bestandsanalyse |
| F17 | P2 | Overworld-weer volgt algemene weerswitch niet | Speler kan weerkosten niet via die optie verminderen | Codebevinding |

### F01 — Guildlogo per update

`scripts/world/remote_player_avatar.gd:243` roept bij elke `apply_state`
`_apply_guild_emblem` aan. Die roept op regel 979
`GuildEmblemTexture.create_nameplate_texture` aan. In
`scripts/ui/guild_emblem_texture.gd` worden alle 1.024 pixels opnieuw gelezen,
kleuren opgebouwd en een nieuwe `ImageTexture` gemaakt. Er is geen vergelijking
met het vorige embleem en geen gedeelde embleemcache.

Warme gemiddelde `apply_state`: **0,181 ms zonder embleem**, **0,463 ms met een
synthetisch gevuld 32×32-embleem**. Dezelfde avatar, 1.000 herhalingen; geen netwerk
of rendering. Het verschil van circa 0,282 ms is terugkerend werk, ook zonder
wijziging van het logo. Honderd vergelijkbare updates betekenen rekenkundig circa
46 ms avatarverwerking; dat is een extrapolatie, geen gemeten netwerkburst.

Aanpak: embleemidentiteit/revisie vergelijken; texture delen per embleeminhoud;
naamplaat en rolbadge alleen bij een echte identiteitswijziging verversen.
Controleer ook guildwissel, lege emblemen en gewijzigde pixels.

### F02 — Stilstaande en verborgen avatars

`remote_player_avatar.gd:225` roept elk frame `_update_animation` aan. Die loopt
vanaf regel 1736 langs de appearance-lagen, bepaalt poses en synchroniseert frames.
De gemeten warme idle-aanroep kost **0,104 ms** voor één standaardavatar.
Lineaire vermenigvuldiging geeft circa 3,1 ms voor 30 en 6,2 ms voor 60 avatars,
zonder hun overige framewerk of rendering. Dit zijn schattingen op basis van de
functiemeting, geen volledige mapmetingen.

`world.gd:2030` verbergt de container en interactie bij “hide other players”, maar
schakelt processing niet uit; `_process` test ook geen zichtbaarheid. Beperk duur
visueel werk tot gewijzigde pose/frame/mount en zichtbare avatars. Behoud de
netwerkpositie en bewegingsvolgorde zodat opnieuw zichtbaar maken geen teleport-
of inhaalanimatie veroorzaakt.

### F03 — Eerste battle-spriteweergave

`scripts/battle/battle_ui/sprite_box.gd:960` gebruikt een cache per loader. Bij een
miss worden spriteframes geladen, uitgesneden en hun zichtbare pixelgrenzen
berekend. `_calculate_sprite_frames_visual_bounds` op regel 767 scant alle frames.
Het metadata-pad vanaf regel 1230 maakt afzonderlijke `ImageTexture`s. Zonder
expliciete anchor worden de bounds daarna nogmaals via auto-anchor berekend.
De aanwezige Charizard-metadata heeft 47 frames en geen anchor.

| Frontsprite | Eerste aanroep | Herhaalde cache-hit | Frames |
| --- | ---: | ---: | ---: |
| Pikachu | 19,536 ms | 0,009 ms | 33 |
| Charizard | 99,911 ms | 0,013 ms | 47 |
| Gyarados | 83,285 ms | 0,015 ms | 59 |

Dit betreft de lokaal beschikbare geanimeerde sprite-assets. Ook een warme
bestandscache voorkomt het opnieuw verwerken in een nieuwe loader niet volledig.
Gebruik eenmaal berekende bounds/anchors, voorbereide metadata en gedeelde
begrensde framecaches. Plan eerste verwerking vóór presentatie of verdeel die over
frames. Test transparantie, hovergebieden, schaal en alle sprite-stijlen.

### F04 — Uiterlijk inkleuren

`scripts/services/character_appearance_service.gd:1257` en `:1279` bouwen voor
iedere animatieframe een gekleurde texture. De pixelpasses in `:1304`/`:1361`
zijn synchroon; atlasbeelden worden via `:1429` naar images gelezen en uitgesneden.
De volledige echte `Gen4_Base_v1`-animatieset opnieuw inkleuren kostte als mediaan
van zeven metingen **41,769 ms**. Caches voorkomen dit voor dezelfde bestaande
variant, maar niet voor een nieuw model/kleur/bewegingsstijl-combinatie.

De synthetische opaque-imageproef gaf 12,0/48,4/190,7 ms voor
128²/256²/512² pixels. Deze beelden zijn geen spelerassets; gebruik ze alleen als
bewijs van pixelafhankelijke groei. Een kleurvariant vooraf genereren of een
palette/shaderoplossing onderzoeken is zinvol, met visuele vergelijkingen voor
huidskleur, contouren en transparantie. Godot documenteert dat `get_image()` data
uit de GPU kan ophalen en daardoor performanceproblemen kan geven bij veelvuldig
gebruik; de headless-proef meet die GPU-kosten niet.
[Godot Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d-method-get-image)

### F05 — Globale scans voor lokale beweging

Backend `gateway/world_presence.py:114` bepaalt vóór en na een update de canonieke
spelerstatus. `_canonical_state_for_user` op regel 349 bouwt daarvoor telkens het
overzicht van alle gebruikers. `broadcast_to_map:246` loopt vervolgens opnieuw
door alle verbindingen, inclusief spelers in andere maps.

| Alle verbindingen | Spelers in de betreffende map | Mediaan per update | p95 |
| ---: | ---: | ---: | ---: |
| 10 | 10 | 0,035 ms | 0,057 ms |
| 100 | 10 | 0,089 ms | 0,107 ms |
| 1.000 | 10 | 0,638 ms | 0,840 ms |
| 100 | 100 | 0,108 ms | 0,121 ms |
| 500 | 500 | 0,446 ms | 0,578 ms |

Werkelijke broncode via AST geladen zonder app-startup/config; fake sockets met
onmiddellijke verzending en minimale spelergegevens. Per geval 20 warm-ups en
200 metingen. Geen JSON-ontvangst, TLS, database of OS-socketkosten meegenomen.
De eerste drie rijen isoleren groei door spelers buiten de map.

Aanpak: indexen per user en map, met expliciete ondersteuning voor meerdere
verbindingen per gebruiker. Behoud canonical-state-keuze, reconnect, snapshot en
rosterrevisies. Spelerscapaciteit moet daarna apart met representatief verkeer
gemeten worden.

### F06–F07 — Langzame ontvangers en updatepieken

Backend `broadcast_to_map` doet `await connection.send_text` binnen één sequentiële
lus zonder eigen send-deadline. Eén fake ontvanger met 50 ms vertraging zorgde voor
**50,2 ms** voltooiingstijd; gezonde ontvangers verderop in dezelfde lus wachten.
Dit blokkeert niet de volledige async eventloop, maar wel die broadcast en het
vervolg van de verzendende speler zijn request-coroutine.

Frontend `world_presence_service.gd:306` leegt alle beschikbare pakketten binnen
één frame. De update bevat bovendien telkens appearance, rollen en het embleem;
`update_position` bevat meerdere legacy-aliases voor dezelfde appearance-velden.
De gateway stuurt volledige status door. Mapbrede verzending groeit bij N bewegende
spelers en U updates per seconde als N×(N−1)×U bezorgingen. De client controleert
publicatie elke 0,06 seconde, maar onderdrukt ongewijzigde signatures: stilstaande
spelers sturen dus niet automatisch continu op die frequentie.

Aanpak: begrensde uitgaande queues per verbinding, expliciete behandeling van
trage ontvangers, compacte movement-updates en een ontvangstbudget per frame.
Preserveer tile-movement-sequences. Chat/PvP-eventloops hebben eveneens geen
frametijdsbudget, maar betrouwbare battle-events mogen niet zomaar worden
samengevoegd of weggegooid.

### F08–F09 — Geheugenlevensduur

`ui_overlay.gd:1390` en `:1553` maken twee `BATTLE_SPRITE_LOADER.new()`-nodes.
Ze worden niet aan de tree toegevoegd en nergens expliciet vrijgegeven.
De geïsoleerde lifetime-proef bevestigt **twee nog geldige loaders nadat de
eigenaar is vrijgegeven**. De probe ruimt deze zelf op; de eindrun heeft geen
resource-leakmelding. Hun texture/framecaches kunnen tijdens echte UI-gebruik
aanzienlijk groter zijn. Dit is een concreet ownership-probleem; de omvang bij
herhaald in-/uitloggen is nog niet gemeten.

Daarnaast zijn de zes static appearance-caches vanaf
`character_appearance_service.gd:159` niet begrensd of geleegd. Nieuwe combinaties
kunnen blijven accumuleren gedurende het proces. Dat is cache-retentie, niet
automatisch een ongecontroleerde leak. Geef losse loaders expliciet ownership
en voeg een gemeten cachebudget toe dat nog gebruikte resources respecteert.

### F10–F11 — PC en database

Backend `account-service/services.py:4079` laadt bij de boxlijst alle boxslots en
bijbehorende volledige Pokémon-payloads. `get_player_pokemon_box:4100` heeft wel
een boxfilter, maar roept eerst `backfill_player_pokemon_box_slots:5186` aan.
Die leest alle Pokémon van de houder plus partij-, box- en mailinformatie. Dit
gebeurt dus ook bij het openen van één kleine box. De frontend vraagt bij de
volledige PC-refresh alle boxes op (`ui_overlay.gd:38775`).

De serializer `_pokemon_payload_with_ownership:8281` leest `original_owner` en
`owner`. De relatievelden in `models.py:1794`/`:1798` hebben geen expliciete eager
loading; de boxquery laadt alleen `.pokemon` met selectinload. Veel verschillende
oorspronkelijke trainers kunnen daardoor extra queries veroorzaken. SQLAlchemy
kan al geladen gebruikers uit de session hergebruiken: dit is niet gegarandeerd
één extra query per Pokémon.
[SQLAlchemy relationship loading](https://docs.sqlalchemy.org/en/20/orm/queryguide/relationships.html#lazy-loading)

Meet queryaantal en payloadgrootte voor kleine/grote collecties en veel geruilde
Pokémon. Verplaats eenmalige herstel/backfill uit het normale leespad zodra de
invariant veilig geborgd is; gebruik compacte boxoverzichten en gerichte eager
loading. Behoud mail-, guildbank-, lending- en ownershipregels.

### F12–F13 — Serviceverkeer op het kritieke pad

`gateway/proxy.py:126` maakt een nieuwe `httpx.AsyncClient` per proxyrequest.
Hetzelfde patroon komt terug in meerdere clients onder
`battle-orchestrator/services/`, waaronder `showdown_client.py` en
`account_service_client.py`. Een bestaande gedeelde pool is al aanwezig in
`gateway/upstream_http.py`; de damage calculator heeft ook pooling. De audit
vindt dus onvolledige toepassing, niet een backend zonder pooling.
Herbruik begrensde clients met expliciete timeouts en shutdown.
[HTTPX clients](https://www.python-httpx.org/advanced/clients/)

`world_presence.py:156` wacht na publicatie op weather-state. De durable provider
ververst een overridecache elke drie seconden en gebruikt een map-lock; een miss
kan een HTTP-request van maximaal drie seconden afwachten. De huidige update is
dan al verstuurd, maar de volgende berichten van dezelfde socket worden pas
verwerkt zodra deze call terugkeert. Onderzoek verversen buiten movement, met
expliciete invalidatie bij weerswijziging en een passende freshness-regel.
Productievertraging hiervan is niet gemeten.

### F14–F15 — Interface en mapwerk

`ui_overlay.gd:1635` bouwt bij `_ready` tientallen schermen/popups, ook voordat ze
geopend worden. In `_process:11802` wordt onder andere elke frame de layout van
inklapknoppen bijgewerkt (`:29637`) en worden permission/role-strings samengesteld
(`:11864`). Veel andere refreshfuncties hebben al een guard of tijdsinterval.
Meet het volledige `_ready` en verschuif dure ongeopende schermen naar eerste
gebruik; maak layout updates afhankelijk van resize/verplaatsing/in- of uitklappen.

De losse UI-scene laden kostte in deze headless-process-run 2,66 s en instantiëren
11,0 ms. Dat eerste getal bevat script/resource-load en is **geen ingame frametijd
of gemeten inlogvertraging**. `_ready` en rendering zijn hierbij niet uitgevoerd.

`scripts/world/map_character_blocking.gd:35` bezoekt recursief alle kinderen van
NPC/Pokémon/interactable-containers voor een vrije bestemming. Een synthetische
kopie van de daadwerkelijke mapstructuur met constant-false blockers meet alleen
de traversalkosten: Cerulean 0,094 ms, Pewter 0,043 ms, Route 3 0,018 ms,
Route 25 0,050 ms. Geen storychecks, physics of NPC-callbackkosten inbegrepen.
Een register per tile of een vlakke blocker-lijst vermijdt het bezoeken van
sprite-, marker- en UI-kinderen; test ook gereserveerde bewegingstiles en gates.

### F16–F17 — Assets, rendering en weer

De login-scene verwijst naar logo's van 3574×3150 en 4173×1399 pixels. Hun
ongecomprimeerde RGBA8-omvang is samen circa **65,2 MiB**. Dat is een rekenschatting,
geen gemeten VRAM-gebruik; afmetingen, importformaten en daadwerkelijke residentie
moeten in de export worden gecontroleerd. De ongebruikte `moon.png` telt niet mee
als aangetoonde runtimebelasting.

De assetproef vond 43 groepen byte-identieke animatie-PNG's. Dezelfde Electric-sheet
staat bijvoorbeeld onder negen paden die door de animatiecatalogi gebruikt worden.
Elk beeld vertegenwoordigt 16,2 MiB in RGBA8. De routercache gebruikt resourcepaden
als sleutel; verschillende paden worden daarmee niet automatisch één cache-entry.
Niet alle varianten zijn tegelijk geladen. Deel de bronassets en controleer alle
animatieconfiguraties. De besparing op PNG-schijfruimte van alle duplicaten is
maar circa 2,1 MiB; mogelijke texture-residentie is hier relevanter.

`overworld_weather_controller.gd:48` rekent elke frame de viewportlayout opnieuw
uit, ook bij helder weer. Het effectieve overworld-weer kijkt naar mapprofiel en
creator-override, maar niet naar `SettingsManager.weather_effects`. De algemene
“Enable Weather Effects”-instelling wordt wel door battleweer gebruikt. Maak de
bedoelde scope duidelijk en bied een werkende overworld-reductie voor zwakkere
hardware. De werkelijke kosten van regen/sneeuw, particles, transparantie,
battlevideo en Windows D3D12/Forward+ zijn met deze headless-proef niet gemeten.

## Wat al goed geregeld is

- Mapscenes gebruiken threaded loading; eerdere Cerulean-depthcorrecties en
  de caches voor NPC-collisionlaag, lokale speler/diepte en tooltip zijn aanwezig.
- Remote-player-volgorde wordt na de vorige taak alleen bij toevoegingen gesorteerd.
- NPC-metadata deelt gelijktijdige requests voor hetzelfde id en locale.
- Battle-animation-router heeft preloading/resourcecaches; sprite-loader heeft
  aantoonbaar snelle cache-hits. Niet iedere move wordt onbeperkt opnieuw geladen.
- AI-search is geïsoleerd in workers met begrensde queue en timeouts. Er is
  battle-TTL-cleanup. Geen bewijs gevonden dat AI standaard de gateway-eventloop
  synchroon bezet; capaciteit/CPU-concurrentie moet met een aparte belastingproef.
- Account-endpoints met databasewerk gebruiken in de onderzochte routes synchrone
  handlers. Geen blanket-conclusie dat async endpoints overal de database blokkeren.
- De exchange heeft gepagineerde querypaden; de boxbevinding mag niet worden
  veralgemeniseerd naar iedere inventaris/marktquery.

## Veilige aanpak in fases

1. **Herhaald lokaal werk:** F01, F02 en F08. Vergelijk identiteitsupdates,
   verborgen/zichtbare spelers, mounts en interfacevervanging. Meet 10/30/60 avatars.
2. **Eerste-weergavepieken en geheugen:** F03, F04, F09 en F16. Deel berekeningen,
   bouw metadata vooraf, begrens caches. Vergelijk assets visueel en meet koude én
   warme runs, plus geheugenterugloop na sluiten/herhaald inloggen.
3. **Realtime schaalbaarheid:** F05–F07, F12–F13. Eerst indexen/pooling en
   ontvangerisolatie; daarna eventuele protocolwijzigingen. Test meerdere sockets
   per user, trage ontvanger, reconnect, volle queues en betrouwbare eventvolgorde.
4. **Collecties en overige UI/mapkosten:** F10–F11, F14–F15, F17. Gebruik
   representatieve fictieve collecties, querytellingen en visuele regressiechecks.
5. **Praktijkprofiling:** release-export op een snelle en zwakke Windows-machine;
   inloggen, drukke map, regen/sneeuw, verstopte spelers, eerste battle, langere
   battle, grote PC en herhaalde relogs. Meet frame-p50/p95/p99, frames boven
   16,7/33,3/50 ms, RAM/VRAM, draw calls, socketqueues en serverresponspercentielen.

Een verbetering is pas bewezen door een voor/na-vergelijking in hetzelfde scenario.
Voor 60 FPS is 16,7 ms het totale framebudget, niet een budget voor iedere functie.
Productieonderzoek en belastingtests vallen buiten deze lokale audit.

## Reproduceren

Vanuit de workspace, met slot C aan deze taak toegewezen:

```sh
ops/worktrees/slot-env slot-c -- godot --headless --path .worktrees/slot-c/frontend --script res://tools/performance/game_audit.gd
python3 .worktrees/slot-c/frontend/tools/performance/asset_audit.py
python3 .worktrees/slot-c/backend/ops/performance/presence_audit.py
```

De frontend-probe voert geen map/world `_ready` uit. De topologieproef vervangt
blocker-callbacks door synthetische constant-false callbacks; eerste experimenten
met niet-geïnitialiseerde gameplaycallbacks zijn verworpen en niet als bewijs
gebruikt. De definitieve run eindigde met exit 0, zonder script- of resource-errors;
wel bestaande UID-fallbackwaarschuwingen. Backendproef: exit 0, geen app-imports,
database of sockets. Assetproef: exit 0, alleen tracked assets gelezen.

Alleen auditdocumentatie en reproduceerbare probes zijn toegevoegd. Geen
gameplayfixes of productieaanpassingen gemaakt; geen volledige integratiegate gedraaid.
