# Onderzoek resterende 53 modelvormen

Datum: 12 oktober 2026. Dit onderzoek behandelt exact de 53 `held`-vormen uit
`alternate_forms_recovery_result.json`. Het voegt **geen gekwalificeerde modellen**
toe. De eerdere 120 + 56 voorbereide paren, hun bewijsbestanden, de geselecteerde
modelrelease en R2 zijn niet gewijzigd.

## Belangrijkste nieuwe bevinding

De vorige intake koppelde **Poltchageist Artisan en Sinistcha Masterpiece aan de
verkeerde bronfamilies**: `pm1123` is Okidogi en `pm1124` is Munkidori. De al eerder
beoordeelde DLC-intake noemt terecht `pm1133` en `pm1134`. Beide juiste families
bevatten een `_11_00`- en `_12_00`-model, inclusief normal/shiny-materiaaldata.
De `_12_00`-resources zijn de concrete herstelkandidaten voor de gemerkte vormen.

De nieuwe binaire vergelijking bewijst:

| Bronfamilie | Botrecords basis/variant | Transformnodes basis/variant | Verschillen |
| --- | ---: | ---: | --- |
| Poltchageist | 77 / 77 | 137 / 137 | Alleen namen van niet-botnodes |
| Sinistcha | 128 / 128 | 176 / 176 | Alleen namen van niet-botnodes |

Alle botrecords, matrices, hiërarchievelden en andere transformgegevens komen
overeen. De hernoemde nodes hebben allemaal `rigIdx = -1`. Dit ondersteunt een
expliciete koppeling van de bestaande bewegingen. Het bewijst nog niet dat een
nieuw geëxporteerd model in de game correct werkt.

De `_12_00`-bronteksturen zijn visueel bekeken: het merkteken is aanwezig. De
1024×1024 normal/shiny-beelden verschillen van de basis; bij Poltchageist betreft
het 29.920 / 29.174 pixels, bij Sinistcha 203.154 / 209.622. De eigen materiaal-
en geometriekoppelingen moeten dus behouden blijven. Alleen de basis hernoemen
zou de variant niet correct herstellen.

De bestaande DLC-receipts beschrijven 9 gereconstrueerde Poltchageist-clips en
8 Sinistcha-clips, met een apart gemaakte rustpose. Dat zijn bestaande
projectbronnen; er is hiervoor niets nieuws gedownload. De native DLC-motionmap
blijft afwezig. Deze audit heeft die historische conversie niet opnieuw gedraaid.

## Uitkomst voor alle 53

Aantal betekent onderzochte vormen, niet een toezegging dat ze al inzetbaar zijn.

| Vervolgwerk | Aantal |
| --- | ---: |
| Verkeerde bronkoppeling gevonden | 2 |
| Koppeling en schaal | 13 |
| Renderer of materiaaltoestand | 3 |
| Zichtbaarheid | 9 |
| Tera-model samenstellen | 4 |
| Effectanimaties | 2 |
| Shiny-palet | 5 |
| Animaties onvolledig | 8 |
| Geen passend model gevonden | 7 |

**Aanpak:** begin met de twee gecorrigeerde thee-bronnen en de eenvoudige
Rockruff-koppeling. Behandel de overige starter/Totem-koppelingen vervolgens
expliciet per vorm en schaal. Rotom Fan is een gerichte rendererproef waard.
Voor de overige groepen is aanvullend werk aan broninterpretatie of gemaakte
animatie/effecten nodig. Noem dat laatste geen verliesloze reconstructie.

## Verdere nieuwe controles

- **21 Blender-bronnen** opnieuw geopend met scripts uitgeschakeld: geneste
  custom properties, object/collection-zichtbaarheid, drivers, NLA, losse actions
  en niet-botcurves uitgelezen. Bij Minior en Cramorant leverde dit geen verborgen
  zichtbaarheid op. De `vs`-groepen van Cramorant zijn daadwerkelijk leeg.
- **32 resourcefamilies** gecontroleerd in de SCVI-modelboom, Biochao-zipinventaris,
  de SV-7z-inventaris en de Z-A-inventaris. De buitenste `SV Every File.zip`
  bevat uitsluitend `SV-Everything.7z`; de tellingen gebruiken daarom de
  inhoud van die 7z. Een negatieve telling geldt alleen voor deze bronnen.
- **Minior/Cramorant:** de onderzochte native TRMMT-switches staan allemaal op 1.
  Dat is geen bewijs welke schelp- of prooimeshes op welk moment zichtbaar horen
  te zijn. Hun passende native motion/sidechannels staan niet in de SV/Z-A-dumps.
- **Primal Kyogre/Groudon:** de basis heeft slaapclips, de eigen Primal-route niet.
  De botrecords verschillen: Kyogre 51 tegenover 59, Groudon 61 tegenover 64.
  Rechtstreeks overzetten heeft dus niet hetzelfde bewijs als de thee-vormen;
  retargeting zou apart moeten worden beoordeeld.
- **Ogerpon Tera:** `_11_99` t/m `_14_99` bevatten gem-mask/effectmodellen. Het
  Teal-mask heeft bijvoorbeeld 15 botrecords tegenover 104 van het basismodel.
  `_15_00` t/m `_18_00` bevatten configuratie, iconen en effectlocators; geen
  zelfstandig volledig model. Er is werk aan samenstelling, binding en shaders
  nodig, niet alleen een bestandsnaam-alias.
- **Ultra Necrozma:** de oudere `pm0800_14_00`-bron bevat ook 756 niet-botcurves in
  losse materiaal-actions. Die informatie mag bij herstel niet verdwijnen.
  Dit levert nog geen ontbrekende damage/faint/sleep-clips op.
- **Xerneas Neutral:** de eigen Z-A defaultwait en battlewait bevatten ieder 12
  materiaaltracks en 6 visibilitytracks. Dit is een concrete route voor
  toestandsonderzoek, nog geen gevalideerd neutral-profiel.
- **Eternamax:** naast benoemde clips bestaat een algemeen benoemde action van
  frame 0–400 en een lange loop. Hun inhoud is nog niet visueel geïdentificeerd;
  er is dus geen definitieve uitspraak dat daarin geen bruikbare pose zit.

De decoders volgen de [TRMMT-schema-indeling](https://github.com/pkZukan/PokeDocs/blob/main/SV/Flatbuffers/model/trmmt.fbs)
en [TRMDL-resourceverwijzingen](https://github.com/pkZukan/PokeDocs/blob/main/SV/Flatbuffers/model/trmdl.fbs).
De artistieke betekenis van een switch volgt niet automatisch uit zijn naam.

## Koppelingen en schaal

De lokale Pokémon Showdown-gevechtsdata geeft onderstaande hoogteverhoudingen.
Dit zijn concrete kandidaten voor een gedeeld model met eigen plaatsing; het
zijn geen teruggevonden oorspronkelijke Totem-modelinstellingen. Eventuele
Totem-aura, genderdetails en overige vormverschillen blijven te controleren.
Bij busted Totem moet de **busted** basis gebruikt worden.

| Vorm | Bestaande basis | Hoogteverhouding |
| --- | --- | ---: |
| araquanid-totem | araquanid | 1.72222 |
| eevee-starter | eevee | 1 |
| gumshoos-totem | gumshoos | 2 |
| kommo-o-totem | kommoo | 1.5 |
| lurantis-totem | lurantis | 1.66667 |
| mimikyu-busted-totem | mimikyubusted | 2 |
| mimikyu-totem | mimikyu | 2 |
| pikachu-starter | pikachu | 1 |
| ribombee-totem | ribombee | 2 |
| rockruff-dusk | rockruff | 1 |
| salazzle-totem | salazzle | 1.75 |
| togedemaru-totem | togedemaru | 2 |
| vikavolt-totem | vikavolt | 1.73333 |

Een aparte alias of plaatsingsregel hoeft geen tweede kopie van geometrie en
texturen te betekenen. De uiteindelijke bundelkoppeling en ruimtewinst zijn
nog niet geïmplementeerd of gemeten.

## Volledige lijst

De machineleesbare `remaining_forms_investigation.json` bevat per vorm ook de
concrete bevinding, vervolgstap, bronverwijzingen en eventuele gecorrigeerde
resource. Historische intake/kwalificatiebestanden zijn bewust behouden; gebruik
voor de twee thee-vormen de nieuwe kandidaatverwijzingen uit dit onderzoek.

| Vorm | Werkcategorie | Resourcekandidaat |
| --- | --- | --- |
| araquanid-totem | Koppeling en schaal | araquanid |
| burmy-sandy | Shiny-palet | pm0412_12_00 |
| burmy-trash | Shiny-palet | pm0412_13_00 |
| castform-rainy | Animaties onvolledig | pm0351_13 |
| castform-snowy | Animaties onvolledig | pm0351_14 |
| castform-sunny | Animaties onvolledig | pm0351_12 |
| cherrim-sunshine | Shiny-palet | pm0421_12_00 |
| cramorant-gorging | Zichtbaarheid | pm0917_13_00 |
| cramorant-gulping | Zichtbaarheid | pm0917_12_00 |
| eevee-starter | Koppeling en schaal | eevee |
| eternatus-eternamax | Animaties onvolledig | pm0940_81_00 |
| greninja-ash | Animaties onvolledig | model_skeleton in pm0725_ash.blend |
| groudon-primal | Animaties onvolledig | pm0383_51_00 |
| gumshoos-totem | Koppeling en schaal | gumshoos |
| kommo-o-totem | Koppeling en schaal | kommoo |
| kyogre-primal | Animaties onvolledig | pm0382_51_00 |
| lurantis-totem | Koppeling en schaal | lurantis |
| mimikyu-busted-totem | Koppeling en schaal | mimikyubusted |
| mimikyu-totem | Koppeling en schaal | mimikyu |
| minior-blue | Zichtbaarheid | pm0824_12_00 |
| minior-green | Zichtbaarheid | pm0824_12_00 |
| minior-indigo | Zichtbaarheid | pm0824_12_00 |
| minior-meteor | Zichtbaarheid | pm0824_11_00 |
| minior-orange | Zichtbaarheid | pm0824_12_00 |
| minior-violet | Zichtbaarheid | pm0824_12_00 |
| minior-yellow | Zichtbaarheid | pm0824_12_00 |
| necrozma-dawn-wings | Effectanimaties | pm0865_13_00 |
| necrozma-dusk-mane | Effectanimaties | pm0865_12_00 |
| necrozma-ultra | Animaties onvolledig | pm0800_14_00 |
| ogerpon-cornerstone-tera | Tera-model samenstellen | Nog niet vastgesteld |
| ogerpon-hearthflame-tera | Tera-model samenstellen | Nog niet vastgesteld |
| ogerpon-teal-tera | Tera-model samenstellen | Nog niet vastgesteld |
| ogerpon-wellspring-tera | Tera-model samenstellen | Nog niet vastgesteld |
| pichu-spiky-eared | Geen passend model gevonden | Nog niet vastgesteld |
| pikachu-belle | Geen passend model gevonden | Nog niet vastgesteld |
| pikachu-cosplay | Geen passend model gevonden | Nog niet vastgesteld |
| pikachu-libre | Geen passend model gevonden | Nog niet vastgesteld |
| pikachu-phd | Geen passend model gevonden | Nog niet vastgesteld |
| pikachu-pop-star | Geen passend model gevonden | Nog niet vastgesteld |
| pikachu-rock-star | Geen passend model gevonden | Nog niet vastgesteld |
| pikachu-starter | Koppeling en schaal | pikachu |
| poltchageist-artisan | Verkeerde bronkoppeling gevonden | pm1133_12_00 |
| ribombee-totem | Koppeling en schaal | ribombee |
| rockruff-dusk | Koppeling en schaal | rockruff |
| rotom-fan | Renderer of materiaaltoestand | pm0479_15_00 |
| salazzle-totem | Koppeling en schaal | salazzle |
| sinistcha-masterpiece | Verkeerde bronkoppeling gevonden | pm1134_12_00 |
| togedemaru-totem | Koppeling en schaal | togedemaru |
| vikavolt-totem | Koppeling en schaal | vikavolt |
| wormadam-sandy | Shiny-palet | pm0413_12_00 |
| wormadam-trash | Shiny-palet | pm0413_13_00 |
| xerneas-neutral | Renderer of materiaaltoestand | pm0768_00_00 |
| zygarde-10 | Renderer of materiaaltoestand | pm0770_11_00 |

## Bewijs en herhaling

`remaining_forms_evidence.json` bewaart de relevante samenvattingen, de concrete
skeletverschillen en SHA-256-pins van bronbestanden en volledige lokale probes.
Het onderzoek staat in `.tmp/remaining-forms-investigation-v1`; eerdere mislukte
proeven zijn behouden. Een bronkandidaat is nadrukkelijk geen runtime-goedkeuring.

Controleer de lijst en, op deze machine, de aanwezige bronbestanden:

```sh
python3 tools/sprite_factory/check_remaining_forms_investigation.py
python3 tools/sprite_factory/check_remaining_forms_investigation.py --verify-local-evidence
```

De native probe is opnieuw te draaien in een toegewezen slot, met de bestaande
SCVI-importer en zijn dependencies op `PYTHONPATH`. Gebruik een nieuw outputpad:

```sh
PYTHONPATH=../.tmp/scvi-importer:../.tmp/scvi-python-deps:tools/sprite_factory \
python3 tools/sprite_factory/remaining_forms_native_probe.py \
  --source-root /run/media/adinho/AFC_Adinho/3d_models \
  --za-root .tmp/alternate-forms-batch-v1/za-sources \
  --za-listing .tmp/alternate-forms-batch-v1/za-listing.txt \
  --sv-listing .tmp/remaining-forms-investigation-v1/sv-listing.txt \
  --output .tmp/remaining-forms-investigation-v1/native-repeat.json
```

De Blender-worker `remaining_forms_source_probe.py` gebruikt het gepinde
`probe-job.json` via de bestaande Flatpak-wrapper, met alleen read-only
brontoegang, `--disable-autoexec` en een aparte schrijfbare outputmap. Stel bij
herhaling nieuwe outputpaden in; de worker overschrijft geen oude proef.

Runtimekwalificatie blijft vervolgens nodig: eigen vorm en kleur bekijken,
ogen/effecten/zichtbaarheid controleren, alle acties en overgangen testen,
battle-schaal/grondcontact meten en de normale/shiny-packpariteit controleren.
Deze audit heeft geen nieuwe runtime-export of platformtest uitgevoerd.

## Uitgevoerde controles

- Exacte, unieke dekking van alle 53 eerdere holds; nul nieuwe toelatingen.
- 573 lokale bron-/bewijspins gecontroleerd.
- Vier negatieve controles verwerpen een dubbele vorm, de oude verkeerde
  thee-koppeling, een onterechte runtime-goedkeuring en gewijzigd bewijs.
- Alle 21 bestaande gerichte Python-tests voor de vormbatch, recovery,
  Therian-vormen en Urshifu geslaagd; eerdere code- en goedkeuringspins intact.
- Python-compilatie en Git-whitespacecontrole geslaagd. Er is geen wijziging
  aan gamegedrag, dus een nieuwe Godot-render of volledige releasegate is niet
  onderdeel van deze onderzoekstaak.
