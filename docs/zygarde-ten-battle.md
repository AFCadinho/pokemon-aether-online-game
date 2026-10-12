# Zygarde 10%: lokale battlekwalificatie

De gebruiker heeft de normal/shiny-preview visueel goedgekeurd met “ziet er goed
uit”. De reconstructie is daarna lokaal gekwalificeerd voor de gamecatalogus.
Er blijven **35 vormen** open; van de oorspronkelijke 229 zijn er nu 194 lokaal
hersteld. Publicatie en releasegoedkeuring staan nog uit. R2, de actieve
release-index en bestaande modelpakketten zijn niet gewijzigd.

## Correctie voor gelijktijdige Pokémon

De preview bevatte gedeelde geanimeerde materialen. Bij twee exemplaren van
dezelfde variant kon de aanvalsgloed daardoor naar de andere Pokémon lekken.
De kandidaat maakt materialen per scene-instantie onafhankelijk. Textures
blijven deelbaar. Een volledige resourcevergelijking na normalisatie van
`resource_local_to_scene` bewijst dat dit de enige inhoudelijke wijziging is.
De shaders, textures, geometrie en animatiecurves zijn gelijk aan de preview.
Een zelfstandige controle bemonstert alle zeven clips op vijf tijdstippen,
voor beide varianten: 70 geslaagde onafhankelijkheidscontroles.

## Controles

Uitgevoerd op Linux met Godot 4.6.2:

- Brongebonden native scènes, 60 Hz plaatsingsmeting en onafhankelijke 120 Hz
  grondcontactcontrole: alle clips blijven minstens 0,025 boven de vloer.
- 48 beelden met beide camerastanden, zijden en varianten: binnen beeld en vrij
  van de HUD-proxy.
- Gecomprimeerd normal/shiny-pakket met gedeelde textures: volledige
  resourcevergelijking, integriteit, afhankelijkheden en vrijgeven slagen.
- 20 pixelidentieke referentie-/pakketbeelden in Mobile/Vulkan.
- De gewone game-laadroute: voorbereiding vóór tonen, team preview in beide
  arena’s, correcte normal/shiny-identiteit en wisselen zonder nieuwe download.
- Echte BattleDisplay in Compatibility/OpenGL en Mobile/Vulkan: normal/shiny,
  normal/normal en shiny/shiny in classic en stadium. Per renderer 126 controles
  zonder materiaaloverdracht, 1.386 controles van emissie/alpha tegen de
  broncurves, 6 faint/vervangingen en 14 screenshots. De echte HP-panelen
  overlappen de idle-modellen niet.
- Een extra laadcontrole gebruikt de uiteindelijke lokale catalogustoelating.

Dit bewijst geen identieke weergave aan de oorspronkelijke Z-A-engine, fysieke
Android-werking, Windows/macOS-werking of een netwerkdownload vanaf R2. De
gebruikte downloads zijn lokaal aangeleverde bestanden via de echte downloader.
De bestaande materiaalvalidators zijn niet verruimd: de embedded shaders werken
in de gewone materiaalroute, buiten de optionele tweepassige belichtingsroute.

## Bewijs en herhalen

`tools/sprite_factory/zygarde_battle_qualification.json` bindt de goedgekeurde
preview, bronbestanden, pakket, controles en code met hashes. Het nieuwe
`release/approved_3d_zygarde_ten_index.json` bevat uitsluitend deze modelpair en
is nog geen actieve release. De game- en launchercatalogus zijn gelijk. Eerdere
kwalificaties en pakketten zijn behouden; regressietests bewaken hun inhoud.

Lokale artifacts blijven onder slot-c/frontend/.tmp/zygarde-battle-v4:

- `runtime-jobs/zygarde-10/native`: de twee zelfstandige scènes;
- `battle/zygarde-10/final`: plaatsingsbeelden en meetrapport;
- `delivery/zygarde-10/shared`: pakket en pixelvergelijking;
- `ui-v3-gl_compatibility` en `ui-v3-mobile`: echte battlebeelden en rapporten.

Vanuit een toegewezen slot gebruikt `zygarde_battle_qualification.py` de fasen
`setup`, `prepare`, `battle`, `delivery`, `ui`, met `POKEAETHER_SLOT` ingesteld.
Alle Godot-processen lopen via `ops/worktrees/slot-env`. De helper gebruikt de
behouden preview-bronnen in hetzelfde slot; outputs vereisen een verse werkmap.
`zygarde_battle_admission.py admit` schrijft de lokale toelating en `finalize`
controleert die via de game. Geen van deze helpers uploadt of publiceert.
