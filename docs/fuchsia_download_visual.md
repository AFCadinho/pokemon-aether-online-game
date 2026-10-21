# Fuchsia City Downloads visual

The current visual is imported from `/home/adinho/Downloads/Fuchsia City.tmx`
(72 × 50 tiles) and its adjacent `Outside Tileset.tsx` / `5GEN_TILESET.png`.
The source files are unchanged.

Reimport in an assigned slot using `tools/import_fuchsia_download_visual.gd`,
passing the source TMX after `--`. This wrapper uses the existing visual importer
and restores the runtime layer contract after reading the older export:

| Original layer | Runtime layer |
| --- | --- |
| Capa de patrones 1 | Ground |
| Capa de patrones 2 | GroundDetail |
| Capa de patrones 3 | Objects |
| Doors | Doors |
| Capa de patrones 4 | ObjectsTop |

Original names are retained as metadata. ObjectsTop receives the normal overlay
z-index. This preserves the existing door source-layer paths and World depth
handling without changing tile placement, artwork, collision, NPCs, map exits,
house scenes or night-light placements.

The downloaded TSX declares an outdated PNG height (48,000 rather than the
actual 50,600 pixels). The importer already derives atlas dimensions from the
actual image. All used cells and the resulting compact atlas were validated.
The source has no tile animations: its fountain/flowers are static. Runtime
nightlights and animated exterior doors remain independent and are preserved.

Validation included all five source layer cell counts, compact-atlas validation,
loading the actual city scene and native-Tiled versus Godot overview comparison
(maximum RGB difference: 1/255 per channel). Both Fuchsia house checks and the
night-light camera/batch checks cover the retained gameplay/rendering contract.
