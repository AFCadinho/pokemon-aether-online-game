# Zygarde 10% — lokale visuele proef

Er is nu een werkende **lokale proefversie voor normal en shiny**. Dit is de
visuele reconstructie waarvoor na het brononderzoek toestemming is gegeven.
De proef is niet toegelaten tot de gamecatalogus, niet gepubliceerd en niet
naar R2 geüpload. Zygarde blijft in de goedkeuringsadministratie een open vorm;
het aantal resterende vormen blijft 36 totdat de proef verder is gekwalificeerd.

## Wat de proef bevat

- De eigen hondgeometrie, skinning, UV's en zeven native animaties uit
  `pm0770_11_00`. De GLB-signatuurcontrole bevestigt dat geometrie en
  animatie-inhoud bij de kleurreconstructie gelijk blijven, ook tussen normal
  en shiny. Ontbrekende posekanalen krijgen expliciete rustwaarden bij wissels.
- Een experimentele kernshader met beide kleur-/normalmapdomeinen, bronkleuren,
  AO, materiaalwaarden en een kijkhoekafhankelijke Fresnel-overgang. De witte
  probe wordt expliciet gebonden; de proef accepteert alleen deze constante
  afbeelding en leidt daar geen algemene cubemapindeling uit af.
- Een experimentele transparante laag met de bron-alphatextuur en dunne
  schermruimtebreking. De kernkleur wordt voor Compatibility correct tussen
  lineaire en sRGB-kleurruimte omgerekend.
- Additieve effectlagen met de bron-UV-animaties en herhalende textures.
  Hun zichtbaarheid, waaronder het speciale-aanvaleffect, volgt de bronkeys.
- De broncurves voor emissie en de alpha van de aanvalsgloed. De kern en
  lichaamsvlakken lichten tijdens de speciale aanval op en vallen daarna terug.
  Per materiaal is bewezen dat de gecombineerde emissielagen dezelfde
  intensiteitscurve hebben. Een altijd brandende laag op `body_a_01` wordt
  afzonderlijk behouden, zodat de animatie die niet onbedoeld uitzet.

De Fresnel-formule, de vervormingssterkte van de kern (0,015 UV-eenheden) en de
schermruimtebreking (0,01) zijn expliciete keuzes voor deze proef. De normale
lichaams- en oogmaterialen gebruiken de bestaande PBR-kleurvertaling, aangevuld
met bronlagen voor emissie. **Een identieke weergave aan de oorspronkelijke
Z-A-engine is niet bewezen.** De bronbestanden zijn ongewijzigd gebleven.

## Resultaat van de controles

Getest op Linux met Godot 4.6.2:

- Compatibility/OpenGL op AMD en Mobile/Vulkan op NVIDIA: beide varianten
  renderen zonder shader- of scriptfouten.
- Alle zeven clips gecontroleerd op tijdsduur, eindige posegrenzen en
  omgekeerde clipvolgorde zonder achtergebleven poses.
- Per renderer 446 videoframes en 4.906 controles van bronzichtbaarheid:
  geen afwijkingen. Dit is een bemonsterde preview, geen volledige battle- of
  releasekwalificatie.
- Per renderer 4.906 controles van de afgespeelde emissie-/alphawaarden tegen
  de broncurves, inclusief het terugzetten bij clipwissels: geen afwijkingen.
- Per renderer 18 posebeelden en 6 borst-close-ups vanuit drie hoeken.
- Vijf regressietests van de eerdere 17 herstelde vormen slagen. Hun catalogi,
  bronbewijzen en release-index zijn niet gewijzigd.
- De experimentele kernshader wordt door de bestaande productievalidator
  afgewezen. De proef verruimt die validator niet.

Dit is geen Windows-, macOS- of fysieke Android-test. De Mobile-renderer is op
deze Linux-machine uitgevoerd. De review gebruikt een losse belichte scène;
de daadwerkelijke battlecamera, HUD, downloads en pakketvalidatie volgen pas
bij eventuele toelating.

## Preview en herhalen

In het behouden slot-c staan onder `.tmp/zygarde-preview-v1`:

- `preview.html`: beide video's en alle close-ups;
- `preview.mp4`: normal en shiny naast elkaar in Compatibility;
- `preview-mobile.mp4`: dezelfde vergelijking in Mobile;
- `preview.png`: overzicht met beide modellen en de kern;
- `review-v4` / `review-mobile-v4`: de afzonderlijke beelden en meetrapporten;
- `native-v4`: de twee gecomprimeerde, zelfstandig laadbare proefscènes.

`tools/sprite_factory/zygarde_preview_result.json` bevat code- en artifacthashes,
de aannames en de testresultaten. Dit bestand is nadrukkelijk geen toelating.

Vanuit het toegewezen frontend-slot maakt
`POKEAETHER_SLOT=slot-c python3 tools/sprite_factory/zygarde_preview.py` de
brongebonden kandidaten. Voer Godot altijd via `ops/worktrees/slot-env slot-c --`
uit. De builder `zygarde_preview_build.gd` gebruikt de absolute werkmap via
`POKEAETHER_ZYGARDE_PREVIEW` en een **nieuwe** submapnaam via
`POKEAETHER_ZYGARDE_REVISION`. Hij maakt `catalog.json` voor de preview.

Plaats die catalogus in een nieuwe reviewmap en geef die door via
`POKEAETHER_PHASE5_REVIEW` aan `zygarde_preview_review.gd`, eenmaal met
`--rendering-method gl_compatibility` en eenmaal met `--rendering-method mobile`.
Beide draaien in het autoloadvrije project onder de werkmap. De gallery-helper
`zygarde_preview_gallery.py --compatibility PAD --mobile PAD` controleert beide
rapporten en maakt de lokale video's met FFmpeg.

De volgende beslissing is de visuele beoordeling van de reconstructie,
vooral de kern, de buitenlaag en de speciale aanval. Daarna kan afzonderlijk
de daadwerkelijke battle- en pakketkwalificatie worden uitgevoerd.
