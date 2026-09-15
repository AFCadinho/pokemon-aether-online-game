# Misty-module met volledige browsercore — technische integratie

## Geïmplementeerd

De frontendloader ondersteunt nu onafhankelijke modules voor Aether Clash en
de expliciete 16 Misty-maps. De map-ID/scene-padlijst is gecontroleerd tegen
`generated/world_access_catalog.json`; deze lijst verleent geen wereldtoegang.
De backend-allowlist en de beschikbare Aethernet-bestemmingen zijn niet gewijzigd.
De browserdemo blijft dus tot Brock beschikbaar, met de bestaande Lobby/minigame.

- Module-downloads lopen naar `user://web_modules` via `HTTPRequest.download_file`;
  geen tweede grote `PackedByteArray` met de volledige response in de loader.
- SHA-256 wordt over het gedownloade bestand gecontroleerd vóór mount.
- Manifesttypes, module-entry, hash en bestandsnaam worden gevalideerd.
- Manifestdownloads zijn begrensd op 1 MiB; PCK-downloads op 32 MiB, timeout 60 s.
- Gelijke gelijktijdige aanvragen delen de lopende download. Een fout blijft
  niet gelatcht: een volgende aanvraag kan opnieuw proberen.
- Mount zonder vervanging van core-assets blijft behouden.
- Directe browserstartup, het toepassen van een browsertransitie en gedeelde
  geautoriseerde teleports wachten op doelmapbeschikbaarheid vóór instantiatie.
- Routewissels lezen vóór de muterende aanvraag opnieuw de servertoegang. Als
  de doelarea één van de 16 Misty-maps is, laden ze eerst de benodigde module.
  De server controleert toegang opnieuw bij het betreden.
- De toekomstige Cerulean-Aethernetreis wacht op de module vóór de reisaanvraag.
  Deze bestemming is server-side nog niet vrijgegeven.
- Bij laadfouten tijdens het toepassen van een verplaatsing blijven de bestaande
  herstel-/cancelpaden actief. Een afgebroken startup keert terug naar login.

## Uitgevoerde combinatieproef

Een aparte `Web Misty Core QA`-export gebruikt dezelfde coreselectie/instellingen,
met een testscene als startpunt. De slot-eigen gewone webexport blijft apart.
De tijdelijk aangepaste projectstartscene is teruggezet vóór commit/integratie.

De QA-export start de werkelijke clientautoloads en de werkelijke moduleloader
in Chromium, via een localhost-only server op poort 8064. Geen accounts,
backendverbindingen, externe requests of verplaatsingen in echte spelersdata.

| Controle | Resultaat |
| --- | --- |
| Alle 16 volledige scenes laden en `instantiate()` / `free()` | PASS |
| Eén module-download voor alle scenes | PASS |
| Acht rondes Route 3 / Cerulean Gym opnieuw construeren en vrijgeven | PASS |
| Resourcecount na iedere ronde | Exact 250 |
| Texture-memoryteller na iedere ronde | Exact 17.332.827 bytes / circa 16,53 MiB |
| 500 ms gesimuleerde downloadvertraging | PASS |
| Raw Mt. Moon-/Cerulean-muziek via browser `decodeAudioData` | PASS, stereo, circa 193/138 s |
| Ontbrekende module-entry | PASS: geen scene gebruikt en geen PCK-download |
| Verkeerde hash | PASS: download afgewezen, geen scene gebruikt |
| PCK HTTP 503 | PASS: fout teruggegeven, geen scene gebruikt |

In alle vier Chromiumscenario’s zijn nul runtime-errors, nul externe requests
en nul UID-waarschuwingen gemeld. De eerdere bare-visualprobe had wel
UID-path-fallbackwarnings; de complete core-registry voorkomt die in deze proef.

Gerichte frontendchecks: manifestvalidatie, modulewachtrij/deduplicatie/retry,
first-gym-contract, Aethernet-effecten, geautoriseerde teleport-inputlock en
web-gameplay-readiness slagen. De twee nieuwe zelfstandige checks zijn aan de
projectchecklijst toegevoegd; de volledige lijst/gate is niet uitgevoerd.

## Wat dit nog niet bewijst

Sceneconstructie test dependencies en initiële objectconstructie, maar voegt de
maps **niet** aan de actieve spelwereld toe. Daardoor zijn NPC-`_ready()`-gedrag,
cutscenes, collisions, story-interacties, gameplay-audioselectie en battleflows
nog niet in de nieuwe browsergebieden uitgespeeld. De audio-test bewijst het
downloaden/decoderen van de raw bronnen, niet de daadwerkelijke music-managerflow.

De acht stabiele samples tonen geen accumulatie na deze constructie/vrijgave-
cyclus. Ze bewijzen geen afwezigheid van leaks tijdens echte mapwissels, battles,
teleports of relog. Evenmin is de volledige Wasm/JS/GPU/proces-RAM gemeten.
De eerder gemeten visual-renderpiek rond 209 MiB is daarom niet wegverklaard.
Rendering op lagere geheugenklassen en langdurige gameplay blijven acceptatiepunten.

HTTP 503 en ontbrekende/ongeldige modules zijn getest; een echte 60 s-timeout,
zeer lage bandbreedte en latere serververplaatsing gevolgd door een laadfout
zijn nog niet live end-to-end getest. De herstelpaden zijn gericht gecontroleerd.

## Volgende stap

Koppel de module aan de normale build-/packagingmanifesten en verruim daarna de
canonieke browsermap-/transitgrens tot de afgesproken Misty-scope. Speel de
nieuwe maps actief uit met geïsoleerde testidentiteiten, inclusief relog,
blackout, teleport, NPC-dialogen en battles. Meet juist in die gameplaycyclus
de hoge renderpieken en resources na mapteardown opnieuw.

Route 5 (alle drie uitgangen), Route 9 en Cerulean Cave blijven permanent dicht.
Voor de volledige story-/pickupchecklist: `browser-misty-preparation.md`.

## Herhalen

Alleen in een taakslot, met de normale projectstartscene schoon en bewaard:

1. Zet `application/run/main_scene` tijdelijk met een patch naar
   `res://tests/web_misty_core_probe.tscn`.
2. Exporteer via `slot-env` preset `Web Misty Core QA` naar de absolute slotmap
   `builds/web-misty-core/index.html`.
3. Zet de projectstartscene met een patch terug naar haar oorspronkelijke waarde,
   ook bij een mislukte export. Commit deze tijdelijke wijziging niet.
4. Gebruik de bestaande Misty-trialpack uit `builds/web-misty-trial/misty-maps.pck`.
5. Start vanuit de frontend-slotmap `python tools/serve_web_misty_core_probe.py`
   en voer in een tweede terminal `node tests/web_misty_core_probe.cjs` uit.
6. Stop de QA-server. Resultaten staan slot-eigen in
   `builds/web-misty-trial/core-results.json`; deze artefacten niet synchroniseren.

Geen volledige paired certificering, promotie, push, publicatie of deployment.
