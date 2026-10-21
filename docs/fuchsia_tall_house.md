# Fuchsia Tall House

The northwest tall house in Fuchsia City uses the supplied
`artist/interior/fuchsia_city/Fuchsia Tall House.tmx` visual (22 × 37 tiles).
Both floors remain in one scene:
`scenes/overworld/kanto/towns/fuchsia_city/tall_house.tscn`.

The implementation reuses Player's House's `floor_visibility_mask.gd` and
`internal_floor_transition.gd` without changing either shared script. The active
floor controls the black masks, camera limits and location name. Position-based
floor detection also supports direct staff arrival upstairs.

| Connection | Trigger / threshold | Arrival |
| --- | --- | --- |
| City → house | Exterior door at (22, 9) | House (10, 31), facing up |
| House → city | Three-tile doorway (9–11, 32) | City (22, 10), facing down |
| Ground → upper | Right stair approached from (14, 31) | Upper (13, 13) |
| Upper → ground | Right stair approached from (14, 13) | Ground (13, 31) |

The narrow stair triggers lie on the right edge of their approach tiles, as in
Player's House. Transfers update player position, movement state, camera and
follower position through the existing shared script. Arrivals avoid the reverse
trigger. Collision contains both floors and blocks furniture and stair holes.

The existing hinged exterior door, `Door74`, is enabled and prepares its open
state when returning from the house. The new map belongs to Fuchsia City's
access group and is registered in both frontend and backend world catalogs and
the extended browser module. Browser partition validation also required adding
the previously registered Route 19 and Route 16 East House to the scope/presets;
those maps' gameplay was not changed. Catalog regeneration synchronizes existing
scene aliases and Route 19's current arrival position as well.

Focused checks:

- `tests/fuchsia_tall_house_check.gd`: real player collision, reachable doorway
  width, furniture, physical stair entry both ways, safe landings, shared lock,
  masks, camera, labels, door animation binding, atlas and catalog destinations.
- `tests/test_web_misty_module_pipeline.py` and export-partition validation.
- Backend `account-service/tests/test_fuchsia_tall_house.py`: catalog loading,
  safe scene arrivals and one map identity for both floors.

Both floors were rendered through World's real depth normalization and inspected
at a 640 × 480 gameplay viewport. Tests do not claim a live authenticated server
round trip.
