# Handmatige end-to-end testguide

Deze guide is bedoeld voor de eigenaar en testers van PokeAether. Je hoeft geen
technische kennis te hebben. Volg de stappen alsof je een gewone speler bent en
noteer alles wat anders werkt dan verwacht.

De guide is een startpunt. Niet iedere tester hoeft alles te doen. Verdeel de
testkaarten vooraf en sla een kaart alleen over als de benodigde functie of
testdata niet beschikbaar is.

## Wat is end-to-end testen?

Bij een end-to-end test doorloop je een complete spelersreis. Je controleert dus
niet alleen of een knop werkt, maar ook of het resultaat daarna overal klopt.

Voorbeeld: vang een Pokémon, controleer daarna de Party, het Pokédex-resultaat,
Pokémon Storage en ten slotte of alles na opnieuw inloggen nog steeds klopt.

## Het doel van deze testweek

Aan het einde van de week willen we antwoord hebben op drie vragen:

1. Kan een nieuwe speler zonder hulp beginnen en de huidige verhaallijn spelen?
2. Werken gevechten, voortgang, opslag en online functies betrouwbaar samen?
3. Blijven belangrijke gegevens correct na een mapwissel, herstart of korte
   verbindingsonderbreking?

Een test is niet bedoeld om te bewijzen dat de game perfect is. Het doel is om
problemen duidelijk en reproduceerbaar te vinden voordat er nieuwe functies
worden toegevoegd.

## Voorbereiding door de testleider

Vul dit blok in voordat de guide naar testers gaat:

```text
Testperiode:
Gameversie/build:
Server/omgeving:
Downloadlink:
Waar bugs melden:
Wie beantwoordt vragen:
Bekende problemen die niet opnieuw gemeld hoeven te worden:
```

Regel daarnaast het volgende:

- één nieuw account per tester voor de eerste spelersreis;
- minstens twee bestaande accounts voor multiplayer-tests;
- indien mogelijk één account met toegang tot latere systemen, zoals Guilds,
  Ranked, mounts en field moves;
- een vaste plek voor resultaten en schermafbeeldingen;
- per testkaart één eigenaar, zodat duidelijk is wie hem uitvoert.

Gebruik alleen toegewezen testaccounts. Deel nooit wachtwoorden, sessies,
privéberichten of andere persoonlijke gegevens in een bugrapport.

## Simpele werkwijze voor testers

1. Noteer vóór het starten de build, je besturingssysteem en je schermresolutie.
2. Begin een testkaart vanuit de genoemde startsituatie.
3. Voer de stappen in de aangegeven volgorde uit.
4. Vergelijk wat je ziet met **Verwacht resultaat**.
5. Geef de kaart één uitkomst: `PASS`, `FAIL`, `BLOCKED` of `SKIPPED`.
6. Maak bij `FAIL` direct een bugrapport met een screenshot of korte video.
7. Ga daarna verder, tenzij je voortgang, account of gevecht vastzit.

Betekenis van de uitkomsten:

| Uitkomst | Wanneer gebruik je dit? |
|---|---|
| `PASS` | Alle stappen werken en het eindresultaat klopt. |
| `FAIL` | Minstens één stap werkt niet of geeft een verkeerd resultaat. |
| `BLOCKED` | De test kan niet verder door een ander probleem. |
| `SKIPPED` | De test was bewust niet toegewezen of de functie is niet beschikbaar. |

Schrijf bij een blokkade altijd op waardoor de test geblokkeerd is. Een lege of
overgeslagen uitslag zegt niets.

## Prioriteiten

- **P0 — altijd testen:** starten, inloggen, nieuwe game, verhaal, opslaan,
  gevechten en opnieuw inloggen.
- **P1 — deze week verdelen:** inventory, Storage, wereld, skills, sociale
  functies en instellingen.
- **P2 — geplande groepssessie:** ruilen, Ranked, Casual, spectaten, Guilds en
  Aether Clash. Hiervoor zijn meerdere spelers of speciale toegang nodig.

Als er weinig tijd is, rond dan eerst alle P0-kaarten af.

---

## P0: belangrijkste spelersreis

### E2E-01 — Launcher, account en login

**Start:** de game is volledig afgesloten.

**Stappen:**

1. Open de launcher en laat hem controleren op updates.
2. Open nieuws of serverstatus als die zichtbaar zijn.
3. Start de game vanuit de launcher.
4. Maak met een toegewezen e-mailadres een nieuw account, of gebruik het
   toegewezen nieuwe account.
5. Probeer één keer bewust een verkeerd wachtwoord en daarna het juiste.
6. Sluit de game volledig, start opnieuw en log nogmaals in.

**Verwacht resultaat:** de launcher blijft bruikbaar, fouten zijn begrijpelijk,
de juiste login werkt en er worden geen lege, vastgelopen of dubbele vensters
getoond.

### E2E-02 — Nieuwe game en personage

**Start:** een account zonder bestaande voortgang.

**Stappen:**

1. Start een nieuwe game en lees alle waarschuwingen en uitleg.
2. Maak een personage en probeer meerdere beschikbare uiterlijkopties.
3. Kies een naam en controleer ook één duidelijk ongeldige naam.
4. Bevestig het personage en betreed de wereld.
5. Loop in alle richtingen, bots tegen muren en objecten en praat met een NPC.
6. Open de belangrijkste menu's en sluit ze weer.

**Verwacht resultaat:** geldige keuzes worden opgeslagen, ongeldige invoer geeft
een duidelijke melding, het personage spawnt correct en kan niet door muren,
NPC's of gesloten grenzen lopen.

### E2E-03 — Van start tot eerste Pokémon

**Start:** direct na E2E-02.

**Stappen:**

1. Volg de aanwijzingen en het Quest Log zonder hulp van een ontwikkelaar.
2. Ga naar Professor Oak en kies een starter.
3. Bekijk de starter in Party en Pokémon Summary.
4. Controleer naam, level, HP, stats, Ability en moves.
5. Speel het eerste verplichte gevecht en gebruik verschillende moves.
6. Praat na afloop opnieuw met relevante NPC's en controleer de queststatus.

**Verwacht resultaat:** het verhaal wijst logisch de weg, de starter wordt maar
één keer ontvangen, de gegevens zijn overal gelijk en het gevecht eindigt zonder
vastloper of dubbele beloning.

### E2E-04 — Eerste routes, wilde Pokémon en herstel

**Start:** een account met starter dat Pallet Town kan verlaten.

**Stappen:**

1. Reis via Route 1 naar Viridian City en betreed onderweg gebouwen en gras.
2. Start een wild gevecht, kies moves, wissel van Pokémon als dat kan en probeer
   te vluchten.
3. Start een nieuw wild gevecht en vang een Pokémon.
4. Controleer de vangst in Party of Pokémon Storage en in de Pokédex.
5. Laat een Pokémon schade oplopen en herstel het team in een Pokémon Center.
6. Verlaat het gebouw, wissel van map en controleer Party en HP opnieuw.

**Verwacht resultaat:** alle mapovergangen plaatsen de speler op een logische
plek, gevechtsacties reageren één keer, de vangst staat op de juiste plek en het
team blijft na genezen volledig hersteld.

### E2E-05 — Huidige Kanto-verhaallijn

**Start:** vervolg het account uit E2E-04.

**Stappen:**

1. Volg uitsluitend het Quest Log, NPC-dialogen en borden.
2. Speel de beschikbare route via Viridian Forest en Pewter City.
3. Versla Brock en controleer badge en beloningen.
4. Reis verder via Route 3 en Mt. Moon naar Cerulean City.
5. Speel Route 24, het Nugget Bridge-gedeelte, Route 25 en Bill's opdracht.
6. Speel de beschikbare Cerulean Gym-verhaallijn en het gevecht met Misty.
7. Controleer na elk hoofdonderdeel het Quest Log, Bag, Trainer Card en de
   toegang tot het volgende gebied.
8. Noteer ieder moment waarop je langer dan vijf minuten niet weet wat je moet
   doen, ook als je uiteindelijk zelf de oplossing vindt.

**Verwacht resultaat:** de speler kan de huidige verhaallijn in logische volgorde
doorlopen, verplichte gevechten en gebeurtenissen starten één keer, beloningen
worden één keer gegeven en afgesloten routes gaan op het juiste moment open.

Als de build eerder eindigt of een genoemd onderdeel nog niet beschikbaar is,
noteer dan het laatste voltooide questdoel. Markeer alleen de niet-beschikbare
stappen als `SKIPPED`; keur de rest van de kaart wel goed of af.

### E2E-06 — Opslaan, afsluiten en hervatten

**Start:** een account met minimaal één badge en twee Pokémon.

**Stappen:**

1. Noteer map, positie, Party, geld, items, quests en badges.
2. Wissel één Pokémon met Pokémon Storage en verander één instelling.
3. Log normaal uit en sluit de game volledig.
4. Start de game opnieuw en log weer in.
5. Vergelijk alle genoteerde gegevens.
6. Loop naar een andere map, wacht kort, sluit nogmaals normaal af en hervat.

**Verwacht resultaat:** belangrijke voortgang is niet verdwenen of verdubbeld,
de speler verschijnt op een geldige plek en de gewijzigde instelling blijft
behouden.

### E2E-07 — Basisgevechten van begin tot eind

**Start:** een team waarmee wilde en Trainer-gevechten mogelijk zijn.

**Stappen:**

1. Rond één wild gevecht af door te winnen.
2. Rond één Trainer-gevecht af met minimaal één Pokémon-wissel.
3. Gebruik een bruikbaar item tijdens een gevecht.
4. Laat indien veilig één Pokémon fainten en speel verder met de volgende.
5. Controleer XP, level-up, eventueel een nieuwe move en beloningen.
6. Verlies indien mogelijk een afzonderlijke teststrijd en controleer de
   blackout/herstelroute.

**Verwacht resultaat:** beurtvolgorde en HP zijn begrijpelijk, gekozen acties
worden maar één keer uitgevoerd, fainted Pokémon verdwijnen niet, beloningen
kloppen en de speler keert na winst of verlies veilig terug naar de wereld.

---

## P1: systemen verdelen over testers

### E2E-08 — Bag, held items, Pokédex en Storage

1. Open iedere Bag-categorie en bekijk meerdere items.
2. Gebruik een toegestaan herstelitem buiten een gevecht.
3. Geef een Pokémon een held item, vervang het en haal het weer terug.
4. Verplaats Pokémon tussen Party en verschillende Storage-boxen.
5. Gebruik zoeken en filters en bekijk Pokémon Summary vanuit Storage.
6. Controleer de gevangen Pokémon in Pokédex en een item in Item Dex.
7. Log opnieuw in en controleer aantallen, Party, box en held items.

**Verwacht resultaat:** informatie en aantallen zijn overal gelijk, een actie
verbruikt of verplaatst precies één item en filters verbergen of dupliceren geen
bezit.

### E2E-09 — Wereld, interacties en bereikbaarheid

1. Test gebouwen, deuren en routeovergangen in minimaal drie gebieden.
2. Loop langs randen, water, bomen, trappen, bruggen en smalle doorgangen.
3. Praat vanuit verschillende richtingen met NPC's en lees borden.
4. Controleer dag/nacht, weer, muziek en geluid bij gebiedswissels.
5. Loop met een follower en, als beschikbaar, met een landmount.
6. Gebruik beschikbare field moves zoals Cut, Flash, Rock Smash, Strength of
   Surf, inclusief één poging zonder de vereiste badge of HM.

**Verwacht resultaat:** de speler raakt niet buiten de map of vast, overgangen
werken in beide richtingen, interacties starten niet dubbel en vergrendelde
acties leggen duidelijk uit wat ontbreekt.

### E2E-10 — Quests, beloningen en skills

1. Accepteer een beschikbare sidequest en lees het doel in het Quest Log.
2. Maak gedeeltelijke voortgang en controleer de teller.
3. Rond de quest af en vergelijk de gemelde beloning met Bag, valuta en skills.
4. Test beschikbare activiteiten zoals Fishing, Thieving en Rock Smash.
5. Controleer XP, cooldowns, mislukking en succes.
6. Wissel van map of log opnieuw in en controleer de voortgang opnieuw.

**Verwacht resultaat:** doelen en tellers lopen één keer op, beloningen komen één
keer binnen en cooldowns of vereisten zijn zichtbaar en blijven correct.

### E2E-11 — Menu's, instellingen en toegankelijkheid

1. Open en sluit alle bereikbare hoofdmenu's via muis en hotkeys.
2. Verander audio, graphics, zoom en controls en pas minstens één hotkey aan.
3. Test venstermodus en minimaal twee schermresoluties.
4. Verander de taal, heropen enkele menu's en voer een normale spelactie uit.
5. Herstart de game en controleer de instellingen.
6. Let op afgekapt tekst, overlappende knoppen, ontbrekende iconen en onleesbare
   kleuren.

**Verwacht resultaat:** er blijft nooit een onzichtbare blokkade over, gewijzigde
controls werken, tekst past in beeld en instellingen blijven na herstart staan.

### E2E-12 — Korte hersteltest

Voer deze kaart alleen uit op een testomgeving of wanneer de testleider hem
expliciet heeft ingepland. Stop geen servers en verander geen serverdata.

1. Sluit de client normaal af terwijl je in de wereld staat en hervat.
2. Onderbreek tijdens een veilige overworld-actie kort de clientverbinding en
   herstel die daarna.
3. Controleer positie, Party, inventory en queststatus.
4. Herhaal dit nooit tijdens een betaling, aankoop of andere waardevolle actie
   zonder aparte toestemming.

**Verwacht resultaat:** de speler krijgt een duidelijke melding, kan opnieuw
verbinden of inloggen en houdt de laatst bevestigde voortgang zonder duplicaten.

---

## P2: tests met twee of meer spelers

Plan deze kaarten op een vast tijdstip. Laat beide testers hun eigen resultaat
en perspectief noteren.

### E2E-13 — Andere spelers, chat en vrienden

1. Laat twee testers naar dezelfde map gaan en bewegen.
2. Controleer aan beide kanten naam, uiterlijk, follower en positie.
3. Verstuur berichten in de beschikbare chatkanalen en een privébericht.
4. Stuur, accepteer en verwijder een vriendschapsverzoek.
5. Open elkaars publieke Trainer Card en gebruik beschikbare speleracties.
6. Laat één tester uitloggen en opnieuw inloggen.

**Verwacht resultaat:** aanwezigheid en berichten verschijnen één keer bij de
juiste spelers, privé-informatie lekt niet en online/offline-status herstelt.

### E2E-14 — Ruilen

Gebruik alleen testitems en test-Pokémon die verloren mogen gaan.

1. Tester A nodigt tester B uit; B weigert de eerste uitnodiging.
2. Stuur een nieuwe uitnodiging en accepteer die.
3. Voeg aan beide kanten een Pokémon of item toe en wijzig het aanbod.
4. Controleer dat een wijziging een eerdere bevestiging ongedaan maakt.
5. Bevestig aan beide kanten en voltooi de ruil.
6. Controleer Party, Storage en Bag bij beide spelers en opnieuw na inloggen.
7. Doe apart één ruil die vóór bevestiging wordt geannuleerd.

**Verwacht resultaat:** beide spelers zien hetzelfde aanbod, eigendom wisselt
precies één keer, annuleren houdt alles bij de oorspronkelijke eigenaar en de
uitkomst blijft na opnieuw inloggen bestaan.

### E2E-15 — Casual, Ranked en spectaten

1. Maak een Casual room aan, laat de ander deelnemen en voltooi een gevecht.
2. Controleer na afloop teams, resultaat en match history.
3. Laat twee geschikte spelers tegelijk aansluiten op de Ranked queue.
4. Speel het Ranked-gevecht uit en controleer timer, resultaat, rating en Battle
   Points aan beide kanten.
5. Herhaal een korte strijd waarin één speler opgeeft.
6. Laat een derde tester een live battle zoeken en spectaten.
7. Controleer dat Casual geen Ranked-rating verandert.

**Verwacht resultaat:** beide clients tonen dezelfde beurten en uitslag, timer en
acties blijven bruikbaar, beloningen worden één keer verwerkt en history,
leaderboard en rating zijn onderling consistent.

### E2E-16 — Guild en Aether Clash

Voer alleen onderdelen uit waarvoor testaccounts toegang en voldoende rechten
hebben.

1. Maak of gebruik een test-Guild en controleer uitnodigen, solliciteren en
   ledenrollen.
2. Test één toegestane storting en opname in Guild-opslag en controleer logs.
3. Test Guild-chat, announcement en zichtbare Guild-informatie.
4. Open de Aether Clash Lobby en controleer uitleg, vendors en beschikbare
   activiteiten.
5. Plan met voldoende spelers één Guild Duel: uitnodigen, accepteren, betreden,
   gevecht, spectaten, resultaat en verlaten.
6. Controleer timer, deelnemers, winnaar, history en eventuele beloningen.

**Verwacht resultaat:** rechten worden afgedwongen, opslag en logs kloppen voor
alle betrokken spelers en een Clash kan zonder vastzittende speler of dubbele
uitslag volledig worden afgerond.

## Dingen waarop je tijdens iedere test let

Meld ook problemen die niet het hoofddoel van de testkaart zijn:

- een crash, freeze, oneindig laadscherm of bediening die niet meer reageert;
- verloren of dubbele Pokémon, items, geld, valuta, XP, badges of questbeloningen;
- op een verkeerde plek spawnen of buiten een map kunnen komen;
- een actie die twee keer gebeurt na één klik;
- verschillende HP, timer, beurt of uitslag bij twee spelers;
- tekst die onduidelijk, afgekapt, onvertaald of fout gespeld is;
- ontbrekende, knipperende of verkeerde sprites, animaties, muziek of geluiden;
- merkbare vertraging, stotteren of steeds trager wordende menu's;
- informatie van een andere speler die privé had moeten blijven.

## Ernst van een bug

| Ernst | Betekenis | Voorbeelden |
|---|---|---|
| **Blocker** | Testen of spelen kan niet verder. | Game start niet, login onmogelijk, account/voortgang kwijt. |
| **Hoog** | Belangrijke functie is kapot of waarde raakt fout. | Gevecht zit vast, quest blokkeert, duplicatie, verkeerde PvP-uitslag. |
| **Middel** | Functie werkt deels of alleen via een omweg. | Eén menuactie faalt, mapovergang werkt maar één kant op. |
| **Laag** | Vooral visueel, tekstueel of klein ongemak. | Verkeerde uitlijning, typefout, kort grafisch knipperen. |

Bij twijfel kies je de lagere ernst en beschrijf je de impact. De testleider kan
de ernst later aanpassen.

## Bugrapport-sjabloon

Kopieer dit voor iedere afzonderlijke bug. Eén rapport per probleem maakt het
makkelijker om te onderzoeken en later opnieuw te testen.

```text
Titel: [kort: wat gaat waar fout?]
Testkaart: [bijvoorbeeld E2E-07]
Ernst: [Blocker / Hoog / Middel / Laag]
Build:
Account/character: [alleen testnaam, geen e-mail of wachtwoord]
Besturingssysteem:
Schermresolutie:
Map/scherm:

Startsituatie:

Stappen om te reproduceren:
1.
2.
3.

Verwacht:

Werkelijk:

Hoe vaak gebeurt het: [1/1, 2/3, soms]
Na opnieuw starten nog aanwezig: [ja / nee / niet getest]
Bijlage: [screenshot/video/log indien gevraagd]
```

Een bruikbare titel is bijvoorbeeld: `Route 1 — speler spawnt in een boom na
terugkeer uit Viridian City`. Alleen `map werkt niet` is niet duidelijk genoeg.

## Dagplanning voor één testweek

| Dag | Focus | Minimale uitkomst |
|---|---|---|
| **Dag 1** | E2E-01 t/m E2E-04 | Launcher, onboarding en eerste vangst door meerdere testers getest. |
| **Dag 2** | E2E-05 en E2E-06 | Hele huidige verhaallijn en persistentie getest. |
| **Dag 3** | E2E-07 t/m E2E-10 | Gevechten, wereld, inventory, quests en skills verdeeld. |
| **Dag 4** | E2E-11 t/m E2E-14 | Instellingen, herstel en sociale functies getest. |
| **Dag 5** | E2E-15 en E2E-16 | Geplande multiplayer-, PvP- en Guild-sessie uitgevoerd. |
| **Laatste ronde** | Belangrijkste fixes opnieuw testen | Iedere Blocker/Hoge bug heeft een hertestresultaat. |

Plan iedere dag een korte afsluiting van maximaal vijftien minuten. Bespreek
alleen:

1. welke kaarten `PASS`, `FAIL`, `BLOCKED` of `SKIPPED` zijn;
2. welke Blocker/Hoge bugs nieuw zijn;
3. wat de volgende dag opnieuw of door iemand anders moet worden getest.

## Dagelijks resultatenoverzicht

```text
Datum:
Build:
Tester:

PASS:
FAIL:
BLOCKED:
SKIPPED:

Nieuwe Blocker/Hoge bugs:
Opnieuw getest en opgelost:
Belangrijkste open vraag:
```

## Wanneer is de testweek klaar?

De testweek is afgerond wanneer:

- iedere P0-kaart door minimaal één tester is uitgevoerd;
- de belangrijkste spelersreis door minimaal één nieuw account is voltooid;
- iedere uitgevoerde kaart een duidelijke uitslag heeft;
- iedere `FAIL` of `BLOCKED` naar een bugrapport verwijst;
- alle Blocker- en Hoge bugs zijn beoordeeld en na een fix opnieuw zijn getest;
- van niet-uitgevoerde P1/P2-kaarten bewust is vastgelegd waarom ze zijn
  overgeslagen.

`PASS` betekent alleen dat de beschreven stappen op de genoemde build en
omgeving goed gingen. Na een nieuwe build hoeven niet alle kaarten opnieuw:
herhaal minimaal de aangepaste kaart, de direct aangrenzende spelersreis en de
korte P0-controle van starten, inloggen, een gevecht en hervatten.
