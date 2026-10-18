# Paintable spin tiles

The Rocket Hideout B1F–B4F scenes have five empty TileMapLayers under `Tiles`.
Paint the corresponding cells in Godot, over the existing visual arrows and
yellow stopping pads:

| Layer name | Behavior |
| --- | --- |
| `SpinUp` | Start or redirect sliding upward |
| `SpinDown` | Start or redirect sliding downward |
| `SpinLeft` | Start or redirect sliding left |
| `SpinRight` | Start or redirect sliding right |
| `SpinStop` | Stop sliding and return control |

Any tile from the layer's TileSet works as a marker. Only cell occupancy and the
exact, case-sensitive layer name matter; no custom tile data or script is needed.
Use a 32×32 TileSet and align the layers with the map grid. These layers can also
be added to other Godot maps, including inside a nested group. They are discovered
through the same layer resolver as Collision and directional ledges.

Paint arrows only on the arrow cells, not along the whole route. Once started,
the character keeps spinning and sliding over ordinary floor until reaching a
stop, a different arrow, or a blocking wall/NPC. A `SpinStop` cell takes priority
over an arrow at the same position; avoid overlapping different arrow layers.
Normal yellow artwork alone does not stop movement: mark that cell in `SpinStop`.

Markers are visible while editing and hidden automatically at runtime. Their
collision and navigation are disabled at runtime; keep map collision in the
existing `Collision` and directional blocking layers. Generated visuals and
artist TMX files do not own this behavior. The added hideout layers are empty so
the artist can author the intended puzzle route.

Movement uses the ordinary tile collision, actor/barrier checks, step signals,
map exits and network movement interpolation. Each forced tile takes 0.12 seconds,
independent of running shoes. The layered character cycles through four facing
poses every 0.07 seconds; the nameplate stays upright. Ledges stop sliding rather
than jumping over an intermediate cell. A closed loop stops safely when the same
position/direction is visited twice.

Sliding owns a separate overworld input lock. External dialogue/battle locks pause
it at a tile boundary and it resumes after those locks end. Reset, teleport,
map changes and player removal release its own lock without clearing
another system's lock. Standing on an arrow after loading can start a slide;
blocked arrows require stepping off and back on before retrying.

Focused check: `tests/spin_tile_movement_check.gd` exercises the actual Player
movement/appearance code and translated, nested marker layers. Run it through
the assigned task slot's `slot-env` wrapper.

Verification also passes the map-layer cache/resolver, story interaction contract
and mount movement timing checks. No live multiplayer playthrough or full paired
release certification was performed. The hideout puzzle cells still need painting
in the empty authoring layers.
