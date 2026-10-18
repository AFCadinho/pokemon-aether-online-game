# Celadon Department Store

Artist source: `/home/adinho/Documents/tiled_pokeaether/kanto/artist/interior/celadon_city/Celadon Department Store.tmx`.
The 42 × 36 visual imports as `celadon_department_store`. Gameplay lives in
`scenes/overworld/kanto/towns/celadon_city/celadon_department_store.tscn`.

The revised visual uses `Ground`, `GroundDetail`, `Objects` and `ObjectsTop`.
The fountain animation spans the latter two layers. Its furniture and two
southern doorway openings differ from the original gameplay layout described
below: visual reimport preserves the existing collision, central exit and
arrivals. Those gameplay footprints need a separate update to match the revised
scenery; the four upper-gallery vendor interactions remain checked.

This is a single interior with eight departments. The broad central staircase
connects the lower shopping floor to the raised northern gallery within the same
map. Tread columns 19–22 and landings at rows 11 and 17 stay open; rail columns
18 and 23 and the balcony edge at rows 12–14 are solid.

Both sliding doors in Celadon City (tiles 12,13 and 16,13) enter at tile 20,32.
The entire three-tile south opening (19–21,33) returns to city tile 12,15, outside
the entry triggers. The store inherits Celadon’s access group, uses indoor
lighting, disables weather and masks outside its 1344 × 1152 canvas.

Collision follows the assembled counter bodies, shelf and display-stand bases,
bench bases, statue plinths, fountain and planters. The public route reaches all
eight customer fronts. Enclosed spaces behind the counters are reserved for
staff; tiny spaces under the northern planter canopies are decorative. A visual
reimport does not regenerate this hand-authored collision.

The new world-access records were produced by `tools/generate_world_access_catalog.tscn`.
Only the new area, three new transitions and city arrival point are included in
this change; unrelated pre-existing Celadon arrival/catalog drift is retained.
Frontend and account-service catalogs contain identical data. The scene is also
registered in the browser’s extended-map loader, scope and export selection.

Focused check: `res://tests/celadon_department_store_check.gd` verifies public
circulation, the stair and balcony, furniture bases, all three exit columns,
both exterior doors, arrival safety, server destinations, the mask, atlas
packing and fountain animation. Backend coverage lives in
`account-service/tests/test_celadon_department_store.py`.
