# Inventarisatie: van 2D- naar 3D-moveanimaties

Momentopname: 5 oktober 2026, lokale `development`-basis `21de5ad077ae96c5c4623d6f3b9a763ec0277a4d`.
Dit document inventariseert de bestaande bronnen en stelt productiegroepen voor.
Het implementeert geen nieuwe animaties en keurt geen moves visueel goed.

## Omvang en huidige dekking

- **193 geregistreerde 2D-moveconfiguraties**, met **192 unieke JSON-tijdlijnen**.
- **184** entries hebben het label `imported_sheet`, **9** `custom_godot_effect`.
  Die labels beschrijven de huidige metadata, niet precies wat zichtbaar getekend wordt:
  ook geïmporteerde entries kunnen procedurele effecten gebruiken of hun sheet verbergen.
- **127 verschillende niet-lege spritesheetpaden**; 6 moves hebben geen sheetpad.
- **44 moves** schakelen een of meer van de **30 procedurele 2D-bouwstenen** in
  die hieronder zijn opgesomd, naast algemene flashes, shakes en spritebewegingen.
- **0 specifieke native move-VFX in de huidige 3D-movedriver**. De bestaande
  fysieke/speciale Pokémon-aanvalsclips blijven wel actief, inclusief beschikbare
  modelgebonden aanvalsvarianten. Dit is dus geen inventaris van ontbrekende modelclips.
- Algemene schade-, stat-, heal-, status-, Z-Power-, Substitute-, weer- en terraineffecten
  bestaan al op aparte event-/lifecycle-routes. Dat de uitkomst zichtbaar is, betekent
  nog niet dat de move zelf een 3D-equivalent heeft.
- **3 extra movefases** uit de algemene effectcatalogus horen bij deze planning:
  `solar_beam_charge`, `electro_shot_charge`, `future_sight_impact`.
- De 193 namen corresponderen met **211 van 919 records** in `move_summary_index.json`:
  de 18 generieke Z-Move-namen hebben daar aparte physical/special-records. De andere
  **708 records** hebben geen eigen entry in deze moveanimatiecatalogus en vallen buiten
  deze eerste pariteitsronde. Dit zijn catalogusaantallen, geen telling van verkrijgbare moves.
  Bijvoorbeeld Surf en Hydro Pump hebben hier nog geen geregistreerde 2D-moveanimatie.

De volledige bronverwijzingen, typen, categorieën, actieve 2D-modules, geluidsbestanden,
bronframes en timing staan per move in
[battle-move-animation-inventory.csv](battle-move-animation-inventory.csv).
`source_frame_duration_seconds` is uitsluitend de getrimde 2D-frameduur gedeeld door
`speed_scale`; het is geen gewenste 3D-duur en telt audiostaarten of overige eventwachttijden niet mee.

## Wat is werkelijk gedeeld?

De movecatalogus heeft geen move-aliaslijst. Gedeelde spritesheets en procedurele modules
zijn goede kandidaten voor herbruikbare 3D-bouwstenen, maar verschillende moves kunnen
andere banen, kleuren, timing en inslagen hebben.

Slechts **Catastropika en 10,000,000 Volt Thunderbolt** wijzen naar dezelfde JSON-tijdlijn
(en delen ook de sheet). Ook een vergelijking van de JSON-inhoud zonder de naam leverde
geen andere identieke tijdlijnen op. De configs van deze twee moves zijn afzonderlijk.
Voor de 3D-port moet hun gewenste visuele identiteit expliciet beoordeeld worden;
neem deze bestaande koppeling niet automatisch over.

### Gedeelde 2D-bouwstenen

Onderstaande groepen komen rechtstreeks uit ingeschakelde configuratieblokken.
Dit zijn huidige 2D-implementaties, geen reeds beschikbare 3D-effecten.

| Bouwsteen | Moves |
| --- | --- |
| `afterimage` | Double Team |
| `background_motion` | Psychic |
| `bloom_doom` | Bloom Doom |
| `bullet_punch` | All-Out Pummeling, Bullet Punch |
| `celestial_charge` | Moonblast |
| `coin_rain` | Make It Rain |
| `court_change` | Court Change |
| `dark_pulse` | Dark Pulse |
| `draco_meteor` | Draco Meteor |
| `dragon_breath` | Dragon Breath |
| `dragon_claw` | Dragon Claw |
| `dragon_dance` | Agility, Dragon Dance |
| `electric_switch` | Gigavolt Havoc, Thunderbolt, Volt Switch |
| `energy_blast` | Focus Blast, Ice Shard, Moonblast, Pyro Ball, Shadow Ball |
| `explosion_burst` | Explosion |
| `fire_stream` | Flamethrower, Scald |
| `focus_aura` | Calm Mind |
| `heat_wave` | Heat Wave |
| `leaf_rush` | Grassy Glide |
| `nasty_plot` | Nasty Plot |
| `orb` | Future Sight |
| `orb_barrage` | Hidden Power |
| `orb_projectile` | Sucker Punch, Weather Ball |
| `psychic_pulse` | Psychic |
| `psychic_shards` | Psyshock |
| `solar_beam` | Electro Shot, Flash Cannon, Hyper Beam, Ice Beam, Solar Beam |
| `sound_wave` | Confusion, Psychic Noise |
| `stat_change` | Tail Whip |
| `thunder_punch` | Thunder Punch |
| `water_splash` | Flip Turn, Water Gun |

### Gedeelde spritesheets

Alle niet-lege sheetpaden die door meerdere moveconfiguraties worden gebruikt.
Een geconfigureerde sheet kan uitgeschakeld zijn via `show_sheet_sprites`; het CSV-bestand
legt dat vast. Deze tabel bewijst daarom bronhergebruik, niet identieke zichtbare animaties.

| Sheetbestand | Moves |
| --- | --- |
| `PRAS- Shadow Sneak.png` | Astonish, Pursuit |
| `PRAS- Ice.png` | Blizzard, Ice Beam, Ice Shard, Subzero Slammer |
| `PRAS- Water.png` | Bubble, Flip Turn, Hydro Vortex |
| `PRAS- Strike.png` | Bullet Punch, Close Combat, Double Kick, Extreme Speed, Fake Out, Frustration, Headlong Rush, High Jump Kick, Knock Off, Low Kick, Peck, Pound, Quick Attack, Sucker Punch, Superpower, Tackle |
| `PRAS- Screech.png` | Calm Mind, Psychic Noise, Screech |
| `PRAS- Catastropika.png` | 10,000,000 Volt Thunderbolt, Catastropika, Electro Shot |
| `PRAS- Slash.png` | Ceaseless Edge, Fury Attack, Scratch, Wing Attack |
| `PRAS- Love.png` | Charm, Return |
| `PRAS- Rock.png` | Continental Crush, Draco Meteor, Earthquake, Head Smash, Rock Throw |
| `PRAS- Sound.png` | Disarming Voice, Growl |
| `PRAS- Dragon Dance.png` | Dragon Dance, Rapid Spin |
| `PRAS- Electric.png` | Charge, Electric Terrain, Gigavolt Havoc, Spark, Stoked Sparksurfer, Thunder Shock, Thunder Wave, Thunderbolt, Volt Switch |
| `PRAS- Fire.png` | Ember, Flamethrower, Inferno Overdrive, Malicious Moonsault, Outrage |
| `PRAS- Elemental Punch.png` | Fire Punch, Ice Punch, Thunder Punch |
| `PRAS- Grass.png` | Grassy Terrain, Growth, Leafage, Razor Leaf, Vine Whip |
| `PRAS- Gust.png` | Gust, Hurricane |
| `PRAS- Smokescreen.png` | Haze, Smokescreen |
| `PRAS- SunMoonZ.png` | Menacing Moonraze Maelstrom, Searing Sunraze Smash |
| `PRAS- Orbs.png` | Misty Terrain, Solar Beam |
| `PRAS- Powders.png` | Poison Powder, Sleep Powder |
| `PRAS- Swords Dance + Signal Beam.png` | Psyshock, Swords Dance |
| `PRAS- Spikes.png` | Spikes, Toxic Spikes |

## Wat kunnen we in 3D hergebruiken?

| Bestaande route | Te behouden / resterende move-uitwerking |
| --- | --- |
| Pokémon-aanvalsclips | Fysiek/speciaal plus gereviewde modelvarianten; ankers en raakmoment moeten bij de nieuwe VFX passen. |
| Damage en faint | Reactie op het bestaande damage-event; de VFX mogen zelf geen schade of uitkomst bepalen. |
| Stat up/down | Resultaat na bijvoorbeeld Swords Dance of Growl; de herkenbare inzet van die move ontbreekt nog. |
| Health up / Wish fulfilled | Heal-resultaat bestaat; Roost, Recover, drains en de eerste Wish-inzet apart beoordelen. |
| Poison/burn/paralysis/sleep/freeze/confusion | Bestaande statusreacties behouden; bijvoorbeeld het projectiel van Toxic of Will-O-Wisp is aparte move-VFX. |
| Protect block | Blokkeerreactie bestaat; het opzetten van de bescherming afzonderlijk beoordelen. |
| Substitute | Doll, reveal/return, hit en HUD bestaan en zijn eerder goedgekeurd; eerst reviewen of de inzet al voldoende is. |
| Vier terrains en weer | Blijvende veldlaag bestaat; move-inzet, overgang en passend geluid daarop aansluiten. Trick Room heeft geen entry in deze 193-movecatalogus. |
| Z-Power | De goedgekeurde power-up blijft; dit keurt de 35 afzonderlijke Z-aanvallen niet automatisch goed. |

De drie timingpilots zijn **Pikachu/Tackle**, **Pikachu/Thunderbolt** en
**Blastoise/Ice Beam**. Ze bevatten gereviewde native raakframes, maar nog geen move-VFX;
ze gelden niet automatisch voor andere Pokémon of aanvalsclips.

## Voorgestelde volgorde

1. **Eerste reviewgroep: Tackle, Scratch, Bite, Ember, Water Gun en Thunder Shock.**
   Hiermee beoordelen we lichaamscontact, klauwen/kaken, projectielen, een stroom en
   elektriciteit op kleine schaal. Alleen Tackle/Pikachu heeft al een raakframepilot;
   de overige gekozen model/move-combinaties moeten nog getimed worden.
2. **Herbruikbare contact- en projectielvarianten uitbreiden.** Bijvoorbeeld Quick Attack,
   Pound, Bullet Punch, Shadow Ball en Water Pulse. Dezelfde bouwsteen mag een eigen
   vorm, kleur, snelheid, geluid en impact behouden.
3. **Langere stralen en gekoppelde fases.** Thunderbolt, Ice Beam, Flamethrower,
   Solar Beam, Electro Shot en Future Sight; de laatste drie inclusief hun aparte fases.
4. **Status, buffs, heals, shields en hazards.** Sluit de move-inzet aan op de bestaande
   generieke uitkomsten en voorkom dubbel afgespeelde effecten/geluiden.
5. **Grote veldinslagen, overige speciale moves en Z-aanvallen.** Eerst de gewone
   bouwstenen stabiliseren; per Z-aanval een afzonderlijke visuele review.

De groepen hieronder zijn een productievoorstel op basis van de move en huidige
configuratie. Ze vervangen de bestaande gameplaycategorie of routing niet.
De catalogusmetadata zijn hiervoor onvoldoende: Moonblast heet bijvoorbeeld `beam`,
terwijl zijn actieve 2D-effect `energy_blast` gebruikt; Outrage staat als
`special_projectile` geregistreerd maar is een fysieke move.

## Afvinkbare movechecklist

| Voorgestelde productiegroep | Moves |
| --- | ---: |
| Lichaamscontact, snelle aanvallen en terugkeer | 22 |
| Slagen en trappen | 13 |
| Klauwen, beten, vleugels en zwepen | 13 |
| Stralen, stromen en elektrische verbindingen | 11 |
| Bollen, losse projectielen en salvo’s | 21 |
| Geluid, psychische effecten en energieoverdracht | 13 |
| Grote veldinslagen en weerachtige aanvallen | 12 |
| Gerichte status- en verzwakkingsmoves | 18 |
| Eigen buffs, herstel en illusies | 15 |
| Schermen, hazards, terrain en andere veldacties | 20 |
| Z-aanvallen | 35 |
| **Totaal** | **193** |

Een vinkje betekent: de complete 3D-presentatie van die move is visueel goedgekeurd,
inclusief benodigde aparte fases, geluid en raakmoment. Bestaande goedkeuringen voor
generieke effecten blijven geldig, maar vinken deze nieuwe movechecklist niet automatisch af.
Alle 193 cataloguskeys komen precies eenmaal voor. De bronconfiguratie blijft in het CSV
zichtbaar; hieronder staan leesbare namen en belangrijke hergebruik-/reviewpunten.

### Lichaamscontact, snelle aanvallen en terugkeer (22)

Korte verplaatsing, contactflits en herstel; elementvarianten en terugkeer apart afstemmen.

- [ ] Aqua Jet (`aquajet`).
- [ ] Body Press (`bodypress`).
- [ ] Extreme Speed (`extremespeed`).
- [ ] Fake Out (`fakeout`).
- [ ] Flip Turn (`flipturn`).
- [ ] Frustration (`frustration`).
- [ ] Giga Impact (`gigaimpact`).
- [ ] Grassy Glide (`grassyglide`).
- [ ] Head Smash (`headsmash`).
- [ ] Headlong Rush (`headlongrush`).
- [ ] Iron Head (`ironhead`).
- [ ] Knock Off (`knockoff`).
- [ ] Outrage (`outrage`).
- [ ] Pursuit (`pursuit`).
- [ ] Quick Attack (`quickattack`).
- [ ] Rapid Spin (`rapidspin`).
- [ ] Return (`return`).
- [ ] Rollout (`rollout`).
- [ ] Spark (`spark`).
- [ ] Tackle (`tackle`).
- [ ] U-turn (`uturn`).
- [ ] Wood Hammer (`woodhammer`).

### Slagen en trappen (13)

Herbruikbare impacts, vuist-/trapaccenten en elementlagen; meerdere treffers volgen de events.

- [ ] Bullet Punch (`bulletpunch`).
- [ ] Close Combat (`closecombat`).
- [ ] Double Kick (`doublekick`).
- [ ] Drain Punch (`drainpunch`) — generieke health_up bestaat; eigen move-effect/energieoverdracht ontbreekt.
- [ ] Fire Punch (`firepunch`).
- [ ] High Jump Kick (`highjumpkick`).
- [ ] Ice Punch (`icepunch`).
- [ ] Low Kick (`lowkick`).
- [ ] Pound (`pound`).
- [ ] Rock Smash (`rocksmash`).
- [ ] Sucker Punch (`suckerpunch`).
- [ ] Superpower (`superpower`).
- [ ] Thunder Punch (`thunderpunch`).

### Klauwen, beten, vleugels en zwepen (13)

Krassen, snijbogen, kaken en lokale contactaccenten met passende modelbeweging.

- [ ] Astonish (`astonish`).
- [ ] Bite (`bite`).
- [ ] Bug Bite (`bugbite`).
- [ ] Ceaseless Edge (`ceaselessedge`).
- [ ] Dragon Claw (`dragonclaw`).
- [ ] Fury Attack (`furyattack`).
- [ ] Kowtow Cleave (`kowtowcleave`).
- [ ] Lick (`lick`).
- [ ] Peck (`peck`).
- [ ] Razor Shell (`razorshell`).
- [ ] Scratch (`scratch`).
- [ ] Vine Whip (`vinewhip`).
- [ ] Wing Attack (`wingattack`).

### Stralen, stromen en elektrische verbindingen (11)

Bronanker → doelanker, opbouw, stroom/straal en inslag; de oplaadfases zijn aparte events.

- [ ] Dragon Breath (`dragonbreath`).
- [ ] Electro Shot (`electroshot`) — ook electro_shot_charge ontbreekt.
- [ ] Flamethrower (`flamethrower`).
- [ ] Flash Cannon (`flashcannon`).
- [ ] Hyper Beam (`hyperbeam`).
- [ ] Ice Beam (`icebeam`).
- [ ] Scald (`scald`).
- [ ] Solar Beam (`solarbeam`) — ook solar_beam_charge ontbreekt.
- [ ] Thunderbolt (`thunderbolt`).
- [ ] Volt Switch (`voltswitch`).
- [ ] Water Gun (`watergun`).

### Bollen, losse projectielen en salvo’s (21)

Een gedeelde baan/inslagbasis met eigen vorm, trail, kleur en timing per move.

- [ ] Bubble (`bubble`).
- [ ] Ember (`ember`).
- [ ] Fairy Wind (`fairywind`).
- [ ] Focus Blast (`focusblast`).
- [ ] Hidden Power (`hiddenpower`).
- [ ] Ice Shard (`iceshard`).
- [ ] Leafage (`leafage`).
- [ ] Magical Leaf (`magicalleaf`).
- [ ] Moonblast (`moonblast`).
- [ ] Mud-Slap (`mudslap`).
- [ ] Poison Sting (`poisonsting`).
- [ ] Pyro Ball (`pyroball`).
- [ ] Razor Leaf (`razorleaf`).
- [ ] Rock Throw (`rockthrow`).
- [ ] Shadow Ball (`shadowball`).
- [ ] Sludge Bomb (`sludgebomb`).
- [ ] Swift (`swift`).
- [ ] Thunder Shock (`thundershock`).
- [ ] Water Pulse (`waterpulse`).
- [ ] Water Shuriken (`watershuriken`).
- [ ] Weather Ball (`weatherball`).

### Geluid, psychische effecten en energieoverdracht (13)

Golven, ringen, lokale psychische effecten en zichtbaar terugstromende energie.

- [ ] Absorb (`absorb`) — generieke health_up bestaat; eigen move-effect/energieoverdracht ontbreekt.
- [ ] Confusion (`confusion`).
- [ ] Dark Pulse (`darkpulse`).
- [ ] Disarming Voice (`disarmingvoice`).
- [ ] Draining Kiss (`drainingkiss`) — generieke health_up bestaat; eigen move-effect/energieoverdracht ontbreekt.
- [ ] Gust (`gust`).
- [ ] Hex (`hex`).
- [ ] Psychic (`psychic`).
- [ ] Psychic Noise (`psychicnoise`).
- [ ] Psyshock (`psyshock`).
- [ ] Screech (`screech`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Sparkling Aria (`sparklingaria`).
- [ ] Supersonic (`supersonic`) — statuspresentatie bestaat na geslaagde toepassing; eigen move-effect ontbreekt.

### Grote veldinslagen en weerachtige aanvallen (12)

Veldgeometrie, vallende objecten en volumeeffecten; houd beide teams en de arena leesbaar.

- [ ] Bleakwind Storm (`bleakwindstorm`).
- [ ] Blizzard (`blizzard`).
- [ ] Draco Meteor (`dracometeor`).
- [ ] Earth Power (`earthpower`).
- [ ] Earthquake (`earthquake`).
- [ ] Explosion (`explosion`).
- [ ] Freeze-Dry (`freezedry`).
- [ ] Heat Wave (`heatwave`).
- [ ] Hurricane (`hurricane`).
- [ ] Make It Rain (`makeitrain`).
- [ ] Powder Snow (`powdersnow`).
- [ ] Tera Starstorm (`terastarstorm`).

### Gerichte status- en verzwakkingsmoves (18)

Toepassing/overdracht van de move; daarna de bestaande status- of statreactie hergebruiken.

- [ ] Baby-Doll Eyes (`babydolleyes`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Charm (`charm`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Encore (`encore`).
- [ ] Growl (`growl`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Leech Seed (`leechseed`) — generieke health_up bestaat; eigen move-effect/energieoverdracht ontbreekt.
- [ ] Leer (`leer`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Poison Powder (`poisonpowder`) — statuspresentatie bestaat na geslaagde toepassing; eigen move-effect ontbreekt.
- [ ] Sand Attack (`sandattack`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Sleep Powder (`sleeppowder`) — statuspresentatie bestaat na geslaagde toepassing; eigen move-effect ontbreekt.
- [ ] Smokescreen (`smokescreen`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Spore (`spore`) — statuspresentatie bestaat na geslaagde toepassing; eigen move-effect ontbreekt.
- [ ] String Shot (`stringshot`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Sweet Scent (`sweetscent`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Tail Whip (`tailwhip`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Taunt (`taunt`).
- [ ] Thunder Wave (`thunderwave`) — statuspresentatie bestaat na geslaagde toepassing; eigen move-effect ontbreekt.
- [ ] Toxic (`toxic`) — statuspresentatie bestaat na geslaagde toepassing; eigen move-effect ontbreekt.
- [ ] Will-O-Wisp (`willowisp`) — statuspresentatie bestaat na geslaagde toepassing; eigen move-effect ontbreekt.

### Eigen buffs, herstel en illusies (15)

Eigen herkenbare move-opbouw; stat/heal-resultaat via de bestaande generieke effecten.

- [ ] Agility (`agility`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Calm Mind (`calmmind`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Charge (`charge`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Defense Curl (`defensecurl`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Double Team (`doubleteam`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Dragon Dance (`dragondance`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Focus Energy (`focusenergy`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Growth (`growth`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Harden (`harden`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Howl (`howl`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Nasty Plot (`nastyplot`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Recover (`recover`) — generieke health_up bestaat; eigen move-effect/energieoverdracht ontbreekt.
- [ ] Roost (`roost`) — generieke health_up bestaat; eigen move-effect/energieoverdracht ontbreekt.
- [ ] Swords Dance (`swordsdance`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.
- [ ] Withdraw (`withdraw`) — stat_up/down herbruikbaar waar een stat-event volgt; eigen move-effect ontbreekt.

### Schermen, hazards, terrain en andere veldacties (20)

Plaatsing/activering onderscheiden van blijvend veldgedrag en van latere resultaten.

- [ ] Aurora Veil (`auroraveil`).
- [ ] Chilly Reception (`chillyreception`) — blijvend sneeuwweer bestaat; eigen inzet/vertrek ontbreekt.
- [ ] Court Change (`courtchange`).
- [ ] Defog (`defog`).
- [ ] Electric Terrain (`electricterrain`) — blijvend 3D-terrain bestaat; eigen move-inzet/geluid en overgang nog beoordelen.
- [ ] Future Sight (`futuresight`) — ook future_sight_impact ontbreekt.
- [ ] Grassy Terrain (`grassyterrain`) — blijvend 3D-terrain bestaat; eigen move-inzet/geluid en overgang nog beoordelen.
- [ ] Haze (`haze`).
- [ ] Light Screen (`lightscreen`).
- [ ] Misty Terrain (`mistyterrain`) — blijvend 3D-terrain bestaat; eigen move-inzet/geluid en overgang nog beoordelen.
- [ ] Protect (`protect`) — 3D protect_block bestaat voor blokkeren; activeren van Protect apart beoordelen.
- [ ] Psychic Terrain (`psychicterrain`) — blijvend 3D-terrain bestaat; eigen move-inzet/geluid en overgang nog beoordelen.
- [ ] Reflect (`reflect`).
- [ ] Spikes (`spikes`).
- [ ] Stealth Rock (`stealthrock`).
- [ ] Sticky Web (`stickyweb`).
- [ ] Substitute (`substitute`) — 3D-doll, hit/reveal/return en HUD bestaan; bepaal bij review of dit ook de move-inzet volledig afdekt.
- [ ] Teleport (`teleport`).
- [ ] Toxic Spikes (`toxicspikes`).
- [ ] Wish (`wish`) — wish_fulfilled bestaat; de eerste Wish-inzet nog uitwerken.

### Z-Moves: afzonderlijke aanvallen (35)

De bestaande Z-Power-activatie blijft; elke daadwerkelijke aanval heeft nog eigen uitwerking nodig.

- [ ] 10,000,000 Volt Thunderbolt (`10000000voltthunderbolt`) — 2D gebruikt Catastropika-data; gewenste eigen identiteit eerst beoordelen.
- [ ] Acid Downpour (`aciddownpour`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] All-Out Pummeling (`alloutpummeling`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Black Hole Eclipse (`blackholeeclipse`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Bloom Doom (`bloomdoom`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Breakneck Blitz (`breakneckblitz`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Catastropika (`catastropika`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Clangorous Soulblaze (`clangoroussoulblaze`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Continental Crush (`continentalcrush`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Corkscrew Crash (`corkscrewcrash`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Devastating Drake (`devastatingdrake`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Extreme Evoboost (`extremeevoboost`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Genesis Supernova (`genesissupernova`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Gigavolt Havoc (`gigavolthavoc`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Guardian of Alola (`guardianofalola`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Hydro Vortex (`hydrovortex`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Inferno Overdrive (`infernooverdrive`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Let’s Snuggle Forever (`letssnuggleforever`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Light That Burns the Sky (`lightthatburnsthesky`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Malicious Moonsault (`maliciousmoonsault`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Menacing Moonraze Maelstrom (`menacingmoonrazemaelstrom`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Never-Ending Nightmare (`neverendingnightmare`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Oceanic Operetta (`oceanicoperetta`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Pulverizing Pancake (`pulverizingpancake`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Savage Spin-Out (`savagespinout`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Searing Sunraze Smash (`searingsunrazesmash`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Shattered Psyche (`shatteredpsyche`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Sinister Arrow Raid (`sinisterarrowraid`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Soul-Stealing 7-Star Strike (`soulstealing7starstrike`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Splintered Stormshards (`splinteredstormshards`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Stoked Sparksurfer (`stokedsparksurfer`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Subzero Slammer (`subzeroslammer`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Supersonic Skystrike (`supersonicskystrike`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Tectonic Rage (`tectonicrage`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.
- [ ] Twinkle Tackle (`twinkletackle`) — Z-Power-activatie bestaat; specifieke Z-aanval ontbreekt.

### Aanvullende movefases (3)

- [ ] Solar Beam: opladen (`solar_beam_charge`), inclusief direct vuren wanneer de events geen laadbeurt bevatten.
- [ ] Electro Shot: opladen (`electro_shot_charge`), inclusief overslaan van opladen volgens de events.
- [ ] Future Sight: vertraagde inslag (`future_sight_impact`) op het latere doel/event.

## Criteria bij het later uitwerken

- De Pokémon blijft zijn passende 3D-aanvalsclip gebruiken; bron- en doelankers volgen
  modelafmetingen en de arena, ook bij cameradraaien en verschillende teamslots.
- Hergebruik bestaande movegeluiden waar passend, met nieuwe cues op het zichtbare
  laden, lanceren en raken. Zet het volledige oude 2D-geluidsschema niet blind aan.
  Tot een move eigen VFX heeft, blijft zijn huidige 3D-movegeluid uit; generieke sounds blijven.
- Miss, immunity, Protect, Substitute, multi-hit, spread, charge en delayed events
  moeten de bestaande uitkomst en volgorde behouden. Geen succesvolle hit suggereren
  voordat de events die bevestigen. Geen tweede damage/stat/heal-reactie toevoegen.
- Respecteer replay-pauze/snelheid, cancel, wisselen, arena teardown, animaties uit
  en echte 2D-fallback. Houd aanval → inslag → damage-reactie compact en synchroon.
- Per reviewgroep ook toetsen met een kleine, grote en vliegende Pokémon en minstens
  de PvP-arena; meerdere modellen kunnen een andere native clip/anker nodig hebben.

## Bronnen en controle

Gecontroleerd in de toegewezen slot-b-worktree:

- [Movecatalogus](../data/battle_move_animations.json), alle 193 entries en hun bron-JSON's.
- [Movemetadata](../data/move_summary_index.json), gekoppeld op dezelfde opgeschoonde weergavenaam als de router; zo blijven Z-varianten herkenbaar.
- [Effectcatalogus](../data/battle_effect_animations.json), inclusief de drie losse movefases.
- [Router](../scripts/battle/battle_animation_router.gd), [3D-movedriver](../scripts/battle/battle_move_presentation_3d.gd) en [timingpilots](../scripts/battle/battle_3d_move_timing.gd).
- [Modelaanvalselectie](../scripts/battle/animations/model_attack_selection.gd), [fysieke intenties](../data/physical_move_animation_intents.json) en [2D-player](../scripts/battle/animations/move_animation_player.gd).
- [Algemene 3D-effecten](battle-common-effects-3d.md), [weather](battle-weather-3d.md) en [terrain](battle-terrain-3d.md).

Controle: iedere cataloguskey exact eenmaal geclassificeerd; alle JSON-tijdlijnen
parseerbaar; alle niet-lege geconfigureerde data-, sheet-, achtergrond-, voorgrond- en
soundpaden aanwezig in de slot; exportaantallen en checklist tegen de catalogus vergeleken.
Dit is een statische inventarisatie, geen visuele goedkeuring van alle 193 bestaande
2D-animaties of een runtime-/audiotest. De bronduur is geen snelheidsdoel voor 3D.
