# Zygarde 10%: resultaat van de herstelpoging

Vervolg: er is inmiddels een expliciet toegestane [lokale visuele proef](zygarde-ten-preview.md)
gemaakt en visueel goedgekeurd. Zie de [lokale battlekwalificatie](zygarde-ten-battle.md)
voor de actuele status. Hieronder staat de eerdere herstelpoging; de genoemde
bronbeperkingen blijven van toepassing.

**Nog niet hersteld of toegelaten.** De 17 eerder herstelde vormen blijven
bruikbaar; het aantal resterende vormen blijft 36. Catalogi, pakketten,
release-indexen en R2 zijn bij deze poging niet gewijzigd.

## Wat nu is vastgesteld

De eigen Z-A-hondvorm `pm0770_11_00` en de zeven benodigde acties zijn aanwezig.
Ook de correct geselecteerde hondvorm in Biochao's `Gen6.zip/pm0770.blend` is
onderzocht. De eerdere `pm0770_12_00`-selectie was de slangvorm.

De ontbrekende bestandsnaam is niet de werkelijke blokkade:

- `pm0770_11_00_fresnel_prb_0.png` bestaat. Deze geëxporteerde afbeelding is
  volledig wit, 128 × 128 pixels. Dat bewijst geen cubemapindeling of shaderformule.
- Beide onderzochte Blender-referenties binden op de kern alleen de eerste
  kleur- en normalmap. De tweede kleurmap, tweede normalmap, AO-map en eigen
  probe ontbreken zelfs in een inventaris die ook ongebruikte nodes meetelt.
- De geïmporteerde shader gebruikt een algemene panorama-afbeelding via zijn
  `fresnel_prb`-schakelaar. Dit is geen onafhankelijke reconstructie van de
  oorspronkelijke `FresnelEffect`-shader.
- De transparante buitenlaag `body_a_02` vereist ook een beoordeelde vertaling
  van `IkCharacterTransparent` met `RefractionMode=Thin`. Kern en buitenlaag
  staan in alle zeven geselecteerde acties aan.
- Het aanvullende materiaal `eff_body_d` heeft een additieve blendinstelling.
  De betreffende mesh wordt tijdens `special_attack` aan/uit gezet; alleen
  een goede stilstaande weergave is dus onvoldoende.

De materiaaltafels leggen instellingen en verwijzingen vast, maar bevatten niet
de berekening waarmee kleuren, breking en Fresnel worden gecombineerd. De
Z-A-archiefinventaris bevat geen `.bnsh`, `.trsha`, `.glsl`, `.hlsl` of `.spv`.
In `SV Every File` staan wel gecompileerde Scarlet/Violet-shaders. Daarmee is
geen overeenkomst met de Z-A-kernshader aangetoond; die bestanden zijn daarom
niet als referentie voor toelating gebruikt.

## Waarom geen voorlopig model is vrijgegeven

Een hernoemde probe, een vlak gekleurde kern of een vergelijking met dezelfde
onvolledige Blender-shader zou het oorspronkelijke probleem niet oplossen.
Een nieuw geschreven effect kan er aannemelijk uitzien, maar zonder onafhankelijke
referentie kan deze poging geen herstel zonder kwaliteitsverlies aantonen.

Voor verdere kwalificatie is de werking van de bijpassende Z-A-shaders nodig,
of voldoende onafhankelijke beelden uit de oorspronkelijke renderer om een
visuele reconstructie te beoordelen. Dat is een ontbrekende referentie, geen
ontbrekend model of ontbrekende animatie. Dit document claimt niet dat het effect
technisch onmogelijk te reconstrueren is.

## Herhaalbare controle

De alleen-lezen proef controleert eerst alle native bronhashes, opent beide
gehashte Blender-bestanden met auto-exec uitgeschakeld en zonder netwerk,
inventariseert de materiaalnodes en vergelijkt die met de normal/shiny-tafels.
Hij maakt geen vervangende modellen en kan niets toelaten of publiceren.

Vanuit het toegewezen frontend-slot:

```sh
POKEAETHER_SLOT=slot-c python3 tools/sprite_factory/zygarde_core_probe.py
PYTHONPATH=tools/sprite_factory python3 -m unittest \
  tools/sprite_factory/test_remaining_forms_repair.py
```

Deze Blender-proef gebruikt de bestaande Flatpak-installatie en
`--factory-startup --disable-autoexec`. Er wordt geen Godot-proces gestart.
Het bewijs staat in `tools/sprite_factory/zygarde_core_probe_result.json`;
de lokale logs en graph-inventarissen staan onder `.tmp/zygarde-ten-core-v1`.
