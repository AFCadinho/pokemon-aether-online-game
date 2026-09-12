# Browser releasecheck — 12 september 2026

Deze check betreft de lokale development-versie. Er is niets gepusht, naar
`main` gepromoveerd of naar productie/Cloudflare gedeployed. Dit is geen
volledige paired releasecertificering.

## Resultaten en bewijsgrenzen

| Onderdeel | Controle |
| --- | --- |
| Story tot Town Map | Echte account-HTTP-handlers met geïsoleerde database: introductie, starter, Oak's Parcel, Mom en Town Map. Dezelfde story verschijnt in het desktopprofiel. |
| PC en vangen | Zes vangsten met gecontroleerde capture-respons; volle party stuurt naar box. Deposit, verplaatsen tussen boxen, withdraw, swap, release, ownership en laatste-party-lidbeveiliging getest. Capture-authority is hierbij een testdouble. |
| Party, healing, winkel, beloningen | Browserroutes sluiten aan op dezelfde canonieke services als desktop, inclusief bestaande eigendoms-, kosten- en battlecontroles. Gerichte account-/battle-tests; geen live kooptransactie uitgevoerd. |
| Bestaande trainer/wildbattle | Browserstartup roept nu dezelfde hervatflow aan. Trainerconflicten bij zowel wild- als trainerstart lezen de bestaande serverbinding; geen account/battle-reset. Hervatten, expiry en settlement gericht getest. |
| Zichtbare spelers | Gatewaytest met één native en twee browseridentiteiten, updates in beide richtingen en vertrek. Godot-test zet rosterberichten om in fysieke avatars. Chromium-screenshot toont beide fixture-avatars. |
| Uiterlijk en mapwissels | Login en wereld hydrateren het canonieke uiterlijk ook in de browser; de remote-avatarcheck rendert de Adinho-onderdelen uit een native presencebericht. Browsermapwissels gebruiken de PCK-loader zonder threadvereiste, zodat een server-side verplaatsing niet meer strandt vóór de doelmap opent. |
| Chat | Bestaande gerichte gateway-mapchat- en browserproxysockettests. Geen live gesprek met twee echte spelers uitgevoerd. |
| AI Sparring | Gerichte controllertests; echte simulatorframes door orchestrator, gateway en Godot live-renderer. Chromium start de battle, toont beide Pokémon, verstuurt Thunderbolt en keert na de fixture-eindrespons terug naar de wereld. Dit gebruikt een deterministische HTTP-testdouble, niet een draaiende productie-AI. |
| Battle-intro bij lage framerate | Herhaalde Chromiumcheck vond een timingrace: de intro wachtte op een al afgelopen tween. Gerichte regressietest reproduceerde de vastloper; de reveal wacht nu uitsluitend op een nog lopende tween. |
| Gen-5-animaties | Browser en desktop pinnen dezelfde vier front/back/shiny assetversies. Chromium vraagt daadwerkelijk Gen-5-metadata en sheets aan; screenshots gecontroleerd. Lokale niet-geversioneerde asset-URL's revalideren nu. De inhoud van de productie-R2-bucket is niet geïnspecteerd. |
| Mail | Tekstmail verzenden, lezen en verwijderen getest. Zowel bulk- als losse attachmentclaims server-side verboden; ook verzending met geld/items/Pokémon verboden om uitwisseling via mail te voorkomen. UI en proxies handhaven dezelfde grens. |
| Trade, Lending, Guild Bank, Aether Clash | Browserinterface blokkeert acties; proxies laten routes niet door. Echte account-handlers weigeren de browsertoken ook met een nagebootste desktopheader. |

## Gerichte controles

- Account-service: `tests.test_web_sessions`, `tests.test_pokemon_boxes`.
- Gateway: `tests.test_map_chat`, `tests.test_web_crossplay`,
  `tests.test_pvp_websocket_endpoint`, `tests.test_training_live`.
- Battle-orchestrator: trainer/wild resume en settlement, relevante battle-create
  tests, training-AI-controller, account-state-adapter en training-live tests.
- Showdown: `tests/battle/training-live-fixture.test.ts`, met die gegenereerde
  frames vervolgens door de orchestrator/gateway/Godot-tests.
- Frontend: `web_gameplay_readiness_check.gd`, `battle_reveal_completion_check.tscn`, PC/mail/servicecontractchecks,
  storycontract, trainer-resume-scene, web-AI-contract en dynamische sprites.
- Beide browserproxies gebruiken `tests/fixtures/web_release_routes.json` als
  gedeelde toegangs-/weigeringsmatrix; packaging controleert Gen-5-versiepariteit.
- Godot-webexport en `tests/web_accounts_browser_smoke.cjs` met in-memory
  accounts en WebSocket-fixtures. Screenshots/logs blijven in de slot-eigen
  `builds/web-accounts-qa/`; simulatorframes in `builds/browser-release-qa/`.

## Nog te controleren vóór een live release

1. Start de nieuwste lokale backendcode en herbouw de browser met
   `./run_web_local.sh --connected`. Een bestaand tabblad of oud exportbestand
   bevat deze fixes niet. Doe dit op een afgesproken moment; herstart geen
   battle-authority midden in actieve gevechten.
2. Doe één echte twee-accountproef: browser ↔ desktop én browser ↔ browser,
   dezelfde map, lopen, chatten en mapwissel. Heropen Adinho's bestaande
   trainerbattle via de normale hervatflow; wis daarvoor geen sessie of battle.
3. Speel live een wild- en trainerbattle uit, vang een Pokémon, verlies een
   battle, herlaad tijdens een battle en probeer AI Sparring met de beoogde
   beschikbare niveaus. Dat verifieert ook de daadwerkelijk draaiende services,
   niet alleen de lokale broncode en testdoubles.
4. De bestaande beperkte browserregio blijft Pallet/Route 1/Viridian met de
   toegestane interieurs; Route 2/22 blijven geblokkeerd. In de Chromiumcheck
   worden ook bestaande desktop-only achtergrondaanvragen voor global buffs,
   global heal, player-actions/hotbar en ranked-overzichten geweigerd. Deze check
   verruimt die functies niet. Er zijn verder twee NPC-metadata-timeoutmeldingen
   bij het vervangen van de initiële map in de fixture, waarna metadata wel
   succesvol laadt. Dit is geen foutloze volledige-gamecertificering.
5. Pas bij expliciete promotie: de complete paired gate voor exact de
   releasecommits. Daarna afzonderlijk toestemming voor push/deploy. Controleer
   op Cloudflare de gepubliceerde assetversies, CORS/cacheheaders en HTTPS/WSS
   en herhaal de live rooktest op `play.pokeaether.com`.
