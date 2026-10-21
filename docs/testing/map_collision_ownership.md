# Map collision belongs to the map author

Static map collision and the resulting walking routes are edited and reviewed by
the user in Godot. Automated release checks must not prescribe that layout.

Map tests no longer assert fixed blocked/open cells, furniture footprints,
collision counts, template equality, spawn/actor walkability or flood-filled
routes through real maps. Those assertions and their traversal helpers are
removed from mixed feature tests; their dialogue, story, scene/catalog wiring,
visual and camera checks remain.

The terrain-dependent Aether Clash bot-anchor spread checksum has also been
removed from the release runner. It must not freeze a manually edited arena.

General collision and movement algorithms, dynamic gates/actor blockers and
collision authoring/export tools retain tests with independent fixtures. A test
may also capture a scene's current authored layer and check that startup leaves
it unchanged. Neither kind of test defines the user's static map layout.

A manually changed collision layer is not evidence of a defect merely because an
old path or expected obstacle no longer matches. Do not add these assertions back
when importing visuals or implementing unrelated map features.
