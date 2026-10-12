# Slaapherstel na goedkeuring van de 14 vormpreviews

De gebruiker keurde de getoonde kleuren en vormtoestanden goed met
“zien er goed uit”. `remaining_forms_visual_approval.json` bindt die uitspraak
aan het exacte eerdere previewrapport. De toen al bekende slaapdefecten zijn
uitdrukkelijk uitgezonderd; deze nieuwe correcties krijgen geen stilzwijgende
visuele, battle- of publicatiegoedkeuring.

De zes betreffende vormen hebben nu een gecorrigeerde lokale normal/shiny-
preview: Burmy Sandy/Trash, Wormadam Sandy/Trash en Cramorant Gorging/Gulping.
Dit vervangt de zes slaapbeperkingen uit
[de vorige previewfase](remaining-colour-visibility-preview.md).

## Wat is aangepast?

**Ogen:** de oorspronkelijke oogatlassen bevatten al een gesloten oog in de
cel rechtsboven. De vorige omzetting gebruikte steeds de geopende cel. Voor
slapen wordt nu de gesloten broncel geselecteerd. Albedo, normal en eventuele
ruwheid-/metaalkaarten gebruiken dezelfde cel, zonder resampling. Alle andere
acties herstellen de oorspronkelijke textures. De vier Burmy/Wormadam-
slaapbewegingen zijn volledig behouden. Er zijn geen nieuwe ogen getekend.

**Cramorant:** de basis-slaapanimatie kent de prooi van deze twee vormen niet.
De correctie behoudt de bestaande beweging van lijf, vleugels, poten en nek,
en de positie van de slapende kop. De kop houdt zijn eigen idle-oriëntatie.
Alle bijbehorende kopdelen, de open snavel en de zichtbare prooi behouden hun
eigen idle-positie ten opzichte van de kop. Deze verbinding wordt op 60 Hz
gebakken in gewone animatietracks. Het is een expliciete samengestelde
slaappose, geen teruggevonden oorspronkelijke vorm-slaapanimatie.

Alleen de prooi aan de oorspronkelijke neergebogen slaapkop bevestigen bleek
onvoldoende: Pikachu's staart kwam onder de voeten. De definitieve kopstand
voorkomt dat. De 84 geposeerde geometriecontroles bevestigen dat de zichtbare
prooi tijdens de hele bemonsterde slaapcyclus boven de onderkant van de vogel
blijft. Dit is nog geen plaatsingscontrole tegen een echte battlevloer.

De geanimeerde oogmaterialen zijn per scene-instantie onafhankelijk. Textures
blijven deelbaar. Alle bestaande acties buiten de gewijzigde slaaptracks,
de meshdata, skins, skeletonstructuur en rustmatrices zijn behouden. Voor de
nieuwe oogselectie worden volledige hersteltracks aan iedere actie toegevoegd.
Er is geen runtime-script, klok of nieuwe gamebrede validator nodig.

## Bekijken

In het behouden frontend-slot-c:

- `.tmp/remaining-forms-sleep-v1/index.html`: normaal/shiny, slaap rondom,
  de oude slaappose en een video van alle acties;
- `.tmp/remaining-forms-sleep-v1/sleep-repairs.png`: overzicht van de twaalf
  gecorrigeerde varianten;
- `review-v2`: definitieve native scènes, volledige actie-opnamen en rapport;
- `sleep-around-v2`: slaapopnamen van voren, opzij, achteren en rondom;
- `check-final-geometry.json`: onafhankelijke functionele controle.

De eerdere kleurenpreview en eerdere bewijsbestanden zijn bewaard. De nieuwe
rapportage staat in `tools/sprite_factory/remaining_forms_sleep_result.json`.

## Validatie

Uitgevoerd op Linux met Godot 4.6.2, Compatibility/OpenGL:

- 12 varianten, 92 clips zonder technische reviewfouten;
- 2.340 frames van de volledige acties en 864 extra slaapframes rondom;
- 88 texturecontroles: resultaat is exact de herhaalde gesloten broncel op
  de oorspronkelijke resolutie;
- 72 meshoppervlakken bytegelijk, plus gelijke skinbinds en skeletonrust;
- 45.210 behouden bone-posecontroles buiten de expliciet aangepaste slaapdelen;
- 3.400 oogtexturecontroles na serialiseren en opnieuw laden;
- 792 controles met twee instanties uit dezelfde PackedScene en wisselende
  slaap-/actietoestanden, zonder overdracht van oogstanden;
- 37.114 onafhankelijke bevestigingscontroles op 120 Hz: maximale numerieke
  afwijking kleiner dan `0.000001` in de gebruikte transformcomponenten;
- 84 geposeerde controles van de onderkant van de prooi tegenover de vogel.

Van 84 opnieuw gerenderde beelden buiten slapen zijn 74 pixelidentiek aan de
vorige preview. De overige tien verschillen op één tot zes pixels van de
409.600. Volledige pixelgelijkheid wordt daarom niet geclaimd; de controles
van geometrie, poses en geopende oogtextures slagen wel exact.

Dit omvat geen echte BattleDisplay, battleplaatsing, pakket/downloadroute,
Mobile/Vulkan of andere besturingssystemen. Er is niets toegevoegd aan de
actieve modelcatalogus of naar R2 geüpload. Er blijven formeel **35 vormen
open**, waarvan de eerste 14 nu een visueel goedgekeurd basisvoorstel hebben.
De zes nieuwe slaapcorrecties zijn apart zichtbaar en getest; battlekwalificatie
en toelating volgen daarna.

## Herhalen in een toegewezen slot

De voorbereiding verifieert de eerder goedgekeurde previewhashes en gebruikt
alleen de bewaarde bronnen uit hetzelfde slot:

```sh
POKEAETHER_SLOT=slot-c python tools/sprite_factory/remaining_forms_sleep.py
```

Gebruik een autoload-vrij project met eigen importcache en symlinks naar
`tools`, `scripts`, `resources` en `data` uit dit slot. Alle Godot-opdrachten
lopen via `ops/worktrees/slot-env slot-c --`.

- `remaining_forms_sleep_build.gd -- STAGE NIEUWE_REVIEWMAP` bouwt native
  scènes; de reviewmap moet nieuw zijn.
- `remaining_forms_preview_review.gd`, met `POKEAETHER_PHASE5_REVIEW`, maakt
  de volledige actie-opnamen.
- `remaining_forms_sleep_review.gd` maakt de aanvullende slaap-rondgang in
  een aparte reviewmap met dezelfde kandidaatcatalogus en slaap-reviewposes.
- `remaining_forms_sleep_check.gd -- CATALOG RAPPORT` vereist een echt
  renderdisplay voor geposeerde meshmetingen en controleert ook twee
  gelijktijdige exemplaren.
- `remaining_forms_sleep_result.py` verifieert de definitieve v2-artifacts en
  maakt de kijkpagina, video's en het beknopte bewijsrapport.

Geen van deze helpers verleent catalogustoelating of publiceert modellen.
