# Fuchsia Red Roof House

The supplied `Fuchsia Red Roof House.png` matches the native render of the
adjacent `Fuchsia Red Roof House.tmx` pixel for pixel. The TMX is imported as
`generated/tiled_visuals/fuchsia_red_roof_house/`; the provided art is unchanged.
The gameplay scene is `scenes/overworld/kanto/towns/fuchsia_city/red_roof_house.tscn`.

| Journey | Doorway tiles | Destination arrival |
| --- | --- | --- |
| Fuchsia → house | City (11–12, 30) | House (6, 15), facing up |
| House → Fuchsia | House (5–6, 16) | City (11, 31), facing down |

The single furnished room uses indoor lighting, disabled weather and the shared
floor mask to center the gameplay camera on the room. Collision contains the
room and black padding, blocks the supplied furniture footprints, and leaves
both threshold cells usable. The artist footprint handoff was hash-checked
against the current TMX before authoring and then verified with the real player
movement rules.

Existing exterior double door `Door75` is enabled. Its activation region covers
both approach columns and its arrival binding prepares the open state when
returning to the city. Exterior collision was already clear at both door tiles.

Both frontend/backend world catalogs, browser scene lookup, extended-module
selection and core exclusions include the new house.

Validation: `tests/fuchsia_red_roof_house_check.gd` exercises actual collision,
furniture approaches, full doorway widths, safe arrivals, facing, camera,
double-door activation, visual atlas and catalog coordinates. Backend
`account-service/tests/test_fuchsia_red_roof_house.py` checks the registered area
and both scene-backed transitions. Browser module tests and catalog freshness
checks also pass. The room was rendered through World's depth normalization at
640 × 480 for visual review. No live authenticated server round trip is claimed.
