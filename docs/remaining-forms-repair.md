# Herstel geselecteerde 18 modelvormen

Van de 53 eerdere holds zijn **17 vormen hersteld**: vier nieuwe normal/shiny-
paren en dertien vormen die bestaande modellen delen. **36 vormen blijven over**:
de 35 buiten deze opdracht plus Zygarde 10%. De wijzigingen zijn lokaal
voorbereid; de geselecteerde release, R2 en productie zijn niet aangepast.

## Herstelde vormen

| Route | Vormen |
| --- | --- |
| Eigen gemerkte bron | Poltchageist Artisan, Sinistcha Masterpiece |
| Bestaande modeldata delen | Araquanid Totem, Eevee Starter, Gumshoos Totem, Kommo-o Totem, Lurantis Totem, Mimikyu Totem, Mimikyu Busted Totem, Pikachu Starter, Ribombee Totem, Rockruff Dusk, Salazzle Totem, Togedemaru Totem, Vikavolt Totem |
| Materiaal/toestand herstellen | Rotom Fan, Xerneas Neutral |

De theevarianten gebruiken hun eigen `pm1133_12_00`/`pm1134_12_00`-geometrie,
merkteken en normal/rare-materiaaltafels. De botten, bindmatrices en hiërarchie
komen exact overeen met de eerder beoordeelde basisanimaties. Alleen expliciet
bewezen namen van niet-botnodes worden vertaald. Hun rustpose volgt de bestaande
gemaakte rustanimatie van de basis; dit is geen teruggevonden native slaapclip.

De dertien gedeelde vormen behouden hun eigen battle-identiteit. Downloaden en
pakketcontrole gebruiken de expliciet gekoppelde basisidentiteit. Totem-schaal,
grondcorrectie, zweefhoogte en bewegingscorrecties worden samen vermenigvuldigd
met de vastgelegde hoogteverhouding. Modelruimte-bounds blijven ongewijzigd.
Mimikyu Busted Totem gebruikt de busted-geometrie; de intacte Totem anticipeert
op die vormwisseling. Dit volgt de bestaande genderpresentatie van de
basismodellen en voegt geen aparte gendergeometrie of nieuwe Totem-aura toe.

Rotom Fan gebruikt een begrensde, expliciet toegelaten shader die de originele
basistekstuur en laagmasker onafhankelijk bemonstert. Hun verschillende
resoluties blijven behouden. De bestaande bronbewegingen, ooganimaties,
zichtbaarheid en statische effectinstellingen blijven behouden.

Xerneas Neutral houdt de zichtbaarheid van zijn eigen `defaultwait`-toestand
vast tijdens alle acties. Daardoor blijven de neutrale hoorns zichtbaar en
blijven de gekleurde gevechtshoorns en rug-effecten verborgen. Alle oorspronkelijke
meshes blijven aanwezig. De eigen oog-UV-animaties worden overgenomen, na bewijs
dat basis- en schaduw-UV's synchroon bewegen. Dit gebruikt de bestaande
PBR-oogvertaling; het is geen claim dat de originele spelengine identiek is.

## Zygarde 10% blijft geblokkeerd

De eigen hondvorm en alle zeven benodigde acties zijn aanwezig. De zichtbare
kern gebruikt echter `FresnelEffect`, twee kleur-/normalmapdomeinen,
`NormalOffset`-breking en een lokale speculaire probe. De kern staat in alle
zeven geselecteerde clips aan. De beschikbare importer zet een algemene
`fresnel_prb`-schakelaar aan, maar bindt de betreffende probe-afbeelding niet.

De aanwezige `*_fresnel_prb_0.png` hernoemen zou alleen de ontbrekende bestandsnaam
oplossen. Het bewijst niet dat reflectie, breking en kernweergave behouden zijn.
Daarom is geen vlakke-kleurvervanging of gedeeltelijk model toegelaten. Een
brongetrouwe shader en een onafhankelijke visuele vergelijking zijn nog nodig.
De concrete materiaalparameters en bron-/visibility-pins staan bij Zygarde in
`tools/sprite_factory/remaining_forms_repair_result.json`.

De vervolgpoging in [zygarde-ten-core.md](zygarde-ten-core.md) bevestigt dat
ook de correct geselecteerde Biochao-hondvorm dezelfde ontbrekende materiaalinputs
heeft. De beschikbare probe-afbeelding is wit; de shaderwerking en transparante
buitenlaag blijven onbewezen. Zygarde is daardoor nog niet toegelaten.

## Omvang en bewijs

- Vier nieuwe pakketten: **30.519.364 bytes** (circa 29,1 MiB).
- Dertien gedeelde vormen: **0 extra modelbytes**.
- 88 exact gelijke frames tussen standalone scenes en gecomprimeerde pakketten.
- 452 animatieovergangen, 34.632 zichtbaarheidssamples en 208 battlebeelden.
- Alle vier nieuwe paren opnieuw getest tegen de toegelaten gamecatalogus.
- Alle dertien koppelingen met normal/shiny getest in classic en stadium:
  26 arena-opnamen, correcte bronhashes, schaal en wissels zonder extra download.
- 26 gerichte Python-tests geslaagd, plus Godot-controles voor gedeelde vormen,
  shaderbegrenzing, bestaande vormnamen en de eerdere Meowstic-genderkoppeling.
- De eerdere 573 auditbewijspins blijven geldig. Alle bestaande model- en
  profielrecords zijn inhoudelijk ongewijzigd.

De proeven zijn uitgevoerd op Linux, Godot 4.6.2, met Compatibility- en
Mobile-rendering. Dit is geen nieuwe Windows-, macOS- of Android-test.
Volledige releasecertificering en publicatie vallen buiten deze taak.

## Bestanden en herhaling

`remaining_forms_repair_result.json` geeft de actuele uitkomst voor alle 53
onderzochte vormen. `remaining_forms_repair_qualification.json` bevat de
kwalificatie, codepins en artifact-pins. De vier pakketten staan in de lokale
`release/approved_3d_remaining_forms_index.json`; deze index selecteert geen
nieuwe productierelease. Werkbestanden staan in `.tmp/remaining-forms-repair-v1`.
De bestaande onderzoeks-/kwalificatiebestanden zijn historische snapshots.

De gedeelde-vormresolver is bewust gewijzigd. De historische receipts blijven
ongewijzigd; alleen deze expliciet opnieuw gekwalificeerde codepin mag via de
nieuwe receipt worden opgevolgd. Alle overige historische codepins blijven
streng gelijk. Regressietests verwerpen ongekwalificeerde wijzigingen.

Voer gerichte controles uit vanuit het toegewezen frontend-slot:

```sh
PYTHONPATH=tools/sprite_factory python3 -m unittest \
  tools/sprite_factory/test_remaining_forms_repair.py \
  tools/sprite_factory/test_alternate_forms_batch.py \
  tools/sprite_factory/test_alternate_forms_recovery.py \
  tools/sprite_factory/test_therian_models.py \
  tools/sprite_factory/test_urshifu_models.py
```

Gebruik `ops/worktrees/slot-env slot-c --` voor Godot. De lichte controles
`tests/shared_form_models_check.gd`, `tests/layered_static_material_check.gd`
en `tests/alternate_model_aliases_check.gd` werken in het diagnostische project.
`tests/meowstic_mega_shared_gender_check.gd` heeft het volledige slotproject en
zijn gebootstrapte assets nodig. De renderproeven gebruiken eveneens het echte
slotproject en eigen slot-userdata, met uitsluitend de gepinde lokale pakketten.

De herstelhelpers schrijven eerst kandidaten, daarna runtime-/appearance-/
battle-/delivery-bewijs. `remaining_forms_admission.py` controleert dit bewijs
voor toelating. Voor gewijzigde broninhoud zijn nieuwe proeven nodig; bestaande
artifact-hashes mogen niet zomaar worden vervangen.
