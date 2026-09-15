# Definitieve browserdemo tot Misty — voorbereiding

De daaropvolgende proefexport is afgerond; zie `browser-misty-trial-results.md`
voor daadwerkelijke pakketgrootte, browserprobe en resterende geheugencontroles.

## Afgesproken scope

De laatste uitbreiding van de browserwereld eindigt na Misty. Route 5 blijft
definitief desktop-only. Ook Route 9 en Cerulean Cave blijven buiten de demo.
Spelers mogen na Misty de beschikbare wereld blijven verkennen; winst logt hen
niet uit en stuurt hen niet automatisch naar desktop.

Alles wat al beschikbaar is blijft behouden, inclusief Route 22, Aethernet,
Aether Clash Lobby en de afzonderlijk geladen minigamemaps. De bestaande
permission-gated staff/dev/testertools blijven onder dezelfde autorisatie vallen.
Guildleden behouden hun bestaande gratis teleport naar Lobby.

De machineleesbare **geplande**, nog niet actieve scope staat in
`browser-misty-scope.json`. Deze bestanden veranderen geen runtime-toegang.
Daarna volgen alleen verbeteringen, optimalisaties en bugfixes, geen extra wereld.

## Maps en grens

16 extra canonieke maps:

| Gebied | Maps |
| --- | --- |
| Route 3 | Buitenmap en Pokémon Center |
| Mt. Moon | 1F, B1F, B2F |
| Route 4 | Buitenmap |
| Cerulean | Buitenmap, Pokémon Center, huizen 1/2/3, bike store, Gym |
| Noordelijk gebied | Route 24, Route 25, Bill’s huis |

Alle scenePaths en transities bestaan in het canonieke backendcatalogus
`account-service/generated/world_access_catalog.json`. Geen tweede set
spawncoördinaten of eigen browserquestlijn ontwerpen.

De nieuwe uitgaande grens bestaat uit vijf transities:

- `kanto_cerulean_city__to_route_5_grass`
- `kanto_cerulean_city__to_route_5_left`
- `kanto_cerulean_city__to_route_5_right`
- `kanto_cerulean_city__to_route_9`
- `kanto_cerulean_city__to_cerulean_cave`

Deze moeten server-side geweigerd blijven, ook na Cascade Badge, met directe
API-aanvragen, gewijzigde clientheaders of desktopaccounts met latere voortgang.
De gewone verhaalvoorwaarden blijven daarnaast gelden: Route 3 gaat pas open
na Brock; Bill en de Cerulean-verhaalfase mogen niet worden overgeslagen.

## Bestaande contracts en benodigde wijzigingen

| Onderdeel | Voor implementatie |
| --- | --- |
| Wereldtoegang | Voeg de 16 IDs toe aan `account-service/web_demo_services.py:WEB_MAP_IDS`. Interne en grens-transities worden daar al uit het canonieke catalogus geprojecteerd. |
| Aethernet | Voeg alleen Cerulean toe aan `WEB_TRANSIT_DESTINATION_IDS`. Houd ontdekking, kosten en gewone reisvoorwaarden intact. Test desktoppositie binnen nieuw gebied en bestaande Lobby-recovery buiten het gebied. |
| Story | Gebruik bestaande `/auth/web/world/story` resolve/complete/claim-services. Maptoegang is nu nog de blokkade voor de nieuwe interacties. Controleer elke cutscene in echte browserruntime. |
| Side quests | De huidige accept-allowlist heet `WEB_FIRST_GYM_SIDE_QUEST_IDS` en bevat zes quests. Catalogus bevat daarnaast `pokemon_fan_club_chairman` buiten deze scope; die niet automatisch vrijgeven. Inventariseer eventuele nieuwe side quests alleen op basis van hun NPC/map en voorwaarden. |
| Pickups | 15 extra geregistreerde pickups op Route 3/4 en Mt. Moon, inclusief twee exclusieve fossielen. De browserclaimroute toetst al `ALLOWED_MAPS`; exclusiviteit, ownership en eenmaal-claimen moeten behouden blijven. |
| Battles | Bestaande trainerdatasets voor Route 3/4/24/25, Mt. Moon en Cerulean Gym. Misty’s bestaande scene gebruikt `kanto_alpha_gym_misty`; questcompletion gebruikt `kanto_alpha_gym_misty_battle`. Deze IDs niet hernoemen voor browser. |
| Exports | De huidige core sluit deze scenes/visuals en Mt. Moon/Cerulean-muziek expliciet uit. Pas presetselectie en required/forbidden PCK-markers samen aan. Cerulean Cave, Route 5/9 en staff previews niet per ongeluk meepakken. |
| Packaging | Wijzig assetProfile `kanto-through-pewter-lobby-core`, modulemanifest/packaging en downloadchecks consistent zodra de nieuwe indeling gekozen is. |
| Tekst/tests | Werk demo-uitleg, `infrastructure/web/README.md` en first-gym-contracttests bij; oude readiness-documenten zijn historische bewijzen, geen actuele scopebron. |

Controleer ook winkels, healing/blackout, fishing, thieving, rock smash,
fiets-/mountinteracties en eventuele activiteiten in deze maps. Mapbeschikbaarheid
betekent niet automatisch dat alle desktop-only functies browserklaar zijn.
Breid geen algemene desktop-API-toegang uit om één NPC werkend te maken.

## Assetmeting op 15 september 2026

Gemeten in slot C na frontendcommit `f33224002`; geen productieassets bekeken.
Som van `.res`, `.tscn` en `.tres` in de 12 aanvullende generated visual directories:

| Visuals | MiB op schijf |
| --- | ---: |
| Route 3 | 0,998 |
| Mt. Moon 1F / B1F / B2F | 1,126 / 1,121 / 0,263 |
| Route 4 | 0,995 |
| Cerulean City / Gym | 1,067 / 1,312 |
| Bike shop / gedeeld huistemplate | 1,293 / 0,378 |
| Route 24 / Route 25 | 0,997 / 1,006 |
| Bill’s huis | 0,381 |
| **Totaal** | **10,939** |

Mt. Moon-muziek is circa 3,525 MiB, Cerulean-muziek circa 2,668 MiB.
`copy_browser_audio()` exposeert nu al alle audio buiten de PCK; deze muziek
opnieuw in de PCK opnemen kan dus duplicatie geven. Controleer daadwerkelijke
afspeelpaden en netwerkrequests voordat muziek aan een module wordt toegevoegd.

De laatste bestaande core-export was 300,9 MiB vóór HTTP-compressie, met een
312 MiB-budget. De visualsom alleen laat nauwelijks marge over als alles naar
de core gaat. Dit is **geen** gemeten nieuwe PCK-delta: gedeelde dependencies,
scripts, NPC-assets, import-remaps en exportselectie kunnen de uitkomst wijzigen.
Downloadgrootte zegt bovendien niets over gedecomprimeerd RAM/GPU-gebruik.

Aanbevolen eerste proef: één optionele `kanto-through-misty-maps`-module voor
deze uitbreiding; Lobby blijft core, Aether Clash blijft zijn eigen module.
Generaliseer de huidige Aether-Clash-specifieke loader alleen zover nodig om
modules per doelmap te selecteren. Laden moet vóór scene-instantiatie gebeuren
bij transitie, rechtstreeks inloggen, Aethernet en blackout/herstel, niet alleen
bij de Route 3-poort. Een modulefout mag geen zwart scherm of kapotte gedeelde
positie achterlaten: download/mount vóór een verplaatsende aanvraag waar
mogelijk, en bied veilig opnieuw proberen bij een al gewijzigde serverpositie.

Nog niet definitief gekozen: core versus optionele module. Eerst een echte
slot-export meten, inclusief payload, HTTP-transfer en browsergeheugen. Het
bestaande budget niet stilzwijgend verhogen. Deze voorbereiding maakt geen
experimentele exportpreset en verandert de huidige preview niet.

## Implementatievolgorde en acceptatie

1. Proefexport en dependencycheck: alle 16 scenes laden, dynamische NPC-assets
   en audio beschikbaar, geen assets buiten scope. Test modulehash, ongeldige
   manifesten, timeout, herladen en rechtstreeks login in Cerulean/Mt. Moon.
2. Gepaard frontend/backendcontract: maps, transities, Cerulean-Aethernet,
   browsergrens en doelmaploader. Eerst gerichte contracts en account-HTTP-tests.
3. Verhaalslice Brock → Misty met bestaande canonieke progression/settlement.
   Extra gerichte tests voor pickups, fossielen, NPC-rewards en sidequests.
4. Echte lokale browser end-to-end, daarna dezelfde voortgang op desktop.
   Geen volledige paired certificering tenzij afzonderlijk gevraagd of voor
   een expliciet geautoriseerde promotie. Geen push, publicatie of deployment.

End-to-end checklist (bestaande `docs/tester-discord-posts.md`, posts 05/06,
is de basis; deze uitbreiding voegt browser- en grenscontrole toe):

- Route 3 vóór/na Brock; alle extra deuren, ladders en terugwegen.
- Mt. Moon: Hiker, vier verdachte Trainers, Miguel, één fossiel, Rocket-ambush,
  ontsnapping en Route 4. Beloningen/cutscenes niet herhalen na relog.
- Cerulean Gym vóór Bill geblokkeerd; Gary vóór Nugget Bridge; vijf brugtrainers
  in volgorde, recruiter, Misty/Dadinho-scene op Route 25.
- Bill aanspreken, computer/cellseparator, herstel en één S.S. Ticket met
  correcte popup-/geluidsvolgorde; Gym daarna beschikbaar.
- Drie Gymtrainers en Misty; Cascade Badge, Water Pulse en Aetherite eenmaal;
  questlog en Trainer Card consistent met desktop.
- Extra pickups en beide fossielkeuzes in aparte runs; dubbele en verkeerde-map
  claims geweigerd. Shop, PC, vangen, verlies/blackout en battle-resume.
- Relog en browserrefresh in nieuwe maps, tijdens dialoog en tijdens battle;
  geen tijdelijke Player House-weergave, onzichtbare avatar of inputlock.
- Cerulean-Aethernet onder gewone voorwaarden; gratis guild-Lobby-reis intact;
  desktopaccount buiten demo krijgt nog steeds expliciete Lobby-recoverykeuze.
- Alle drie Route 5-uitgangen plus Route 9 en Cerulean Cave blijven geweigerd,
  zowel vóór als na Misty. Beschikbare gebieden blijven na winst speelbaar.

## Voorbereidingsbewijs

- Canonieke mapcatalogus: alle 16 aanvullende IDs gevonden; vijf nieuwe
  uitgaande grens-transities gevonden.
- `generated_map_texture_storage_check.gd`: PASS, 255 lossless portable textures.
- Dit bewijs betreft statische beschikbaarheid/compressie, niet een geslaagde
  Misty-browserplaythrough, nieuwe export of live backendtest.
