extends RefCounted

# Deliberately local and limited to three visual-test species. The rendered
# derivatives live outside res:// and are never part of a release asset pack.
const OUTPUT_ROOT := "res://../.tmp/dratini-hd-battle-poc"
const DUEL_OUTPUT_ROOT := "res://../.tmp/dragonite-gyarados-poc/runtime"
const MOVE_INDEX_PATH := "res://data/move_summary_index.json"
const ACTIONS := ["idle", "physical_attack", "special_attack", "damage", "sleep", "faint_start", "faint_hold"]
const LOOP_ACTIONS := ["idle", "sleep"]
const ACTION_SPEED := {
	"idle": 1.0,
	"physical_attack": 3.0,
	"special_attack": 3.0,
	"damage": 2.0,
	"sleep": 1.0,
	"faint_start": 3.0,
	"faint_hold": 1.0,
}
const RENDER_SCALE := {
	"dratini": {"front": 1.74, "back": 1.67},
	"dragonite": {"front": 1.0, "back": 1.0},
	"gyarados": {"front": 1.0, "back": 1.0},
}
const DISPLAY_SCALE_MULTIPLIER := {
	"gyarados": 1.3,
}
const POSITION_OFFSET := {
	"dratini": {"front": Vector2(-10, 8), "back": Vector2(-12, 12)},
	"dragonite": {"front": Vector2(-10, 7), "back": Vector2(-12, 0)},
	"gyarados": {"front": Vector2(4, 21), "back": Vector2(-27, 18)},
}

static var _move_index: Dictionary = {}
static var _frames_by_side: Dictionary = {}

static func is_enabled_for(species: String, side: String, shiny: bool) -> bool:
	var species_key := species.strip_edges().to_lower()
	return (
		(
			(species_key == "dratini" and OS.get_environment("POKEAETHER_DRATINI_HD") == "1")
			or (species_key in ["dragonite", "gyarados"] and OS.get_environment("POKEAETHER_HD_DUEL_POC") == "1")
		)
		and side in ["front", "back"]
		and not shiny
	)


static func load_frames(species: String, side: String) -> SpriteFrames:
	var species_key := species.strip_edges().to_lower()
	var cache_key := "%s:%s" % [species_key, side]
	if _frames_by_side.has(cache_key):
		return _frames_by_side[cache_key] as SpriteFrames
	var root := ""
	if species_key == "dratini":
		root = OS.get_environment("POKEAETHER_DRATINI_HD_DIR").strip_edges()
	else:
		root = OS.get_environment("POKEAETHER_HD_DUEL_POC_DIR").strip_edges()
	if root.is_empty():
		root = ProjectSettings.globalize_path(OUTPUT_ROOT if species_key == "dratini" else DUEL_OUTPUT_ROOT)
	if species_key != "dratini":
		root = root.path_join(species_key)
	var manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("manifest.json")))
	if not manifest_value is Dictionary:
		push_warning("HD battle POC: missing local manifest for %s; using the normal sprite." % species_key)
		return null
	var manifest: Dictionary = manifest_value
	var views: Dictionary = manifest.get("views", {})
	var action_data: Dictionary = views.get(side, {})
	var cell_size := int(manifest.get("cell_size", 0))
	var fps := float(manifest.get("fps", 0.0))
	if action_data.is_empty() or cell_size <= 0 or fps <= 0.0:
		return null
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for action: String in ACTIONS:
		var entry: Dictionary = action_data.get(action, {})
		var count := int(entry.get("count", 0))
		var columns := int(entry.get("columns", 0))
		if count <= 0 or columns <= 0:
			return null
		var image := Image.new()
		var image_path := root.path_join(side).path_join(str(entry.get("file", "")))
		if image.load(image_path) != OK:
			push_warning("HD battle POC: could not read %s; using the normal sprite." % image_path)
			return null
		var texture := ImageTexture.create_from_image(image)
		frames.add_animation(action)
		frames.set_animation_speed(action, fps)
		frames.set_animation_loop(action, action in LOOP_ACTIONS)
		for index: int in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2i((index % columns) * cell_size, int(index / columns) * cell_size, cell_size, cell_size)
			atlas.filter_clip = true
			frames.add_frame(action, atlas)
	frames.set_meta("dratini_hd_poc", true)
	_frames_by_side[cache_key] = frames
	return frames


static func attack_action(move_name: String) -> String:
	if _move_index.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOVE_INDEX_PATH))
		if parsed is Dictionary:
			_move_index = parsed
	var key := move_name.strip_edges().to_lower().replace(" ", "-").replace("_", "-")
	var move_data: Dictionary = _move_index.get(key, {})
	return "physical_attack" if str(move_data.get("category", "")).to_lower() == "physical" else "special_attack"

static func speed_for(action: String, species: String = "dratini") -> float:
	if species.strip_edges().to_lower() == "gyarados":
		return float({
			"idle": 1.0, "physical_attack": 1.4, "special_attack": 1.4,
			"damage": 1.0, "sleep": 1.0, "faint_start": 1.4, "faint_hold": 1.0,
		}.get(action, 1.0))
	return float(ACTION_SPEED.get(action, 1.0))


static func stage_variant() -> String:
	return "clean" if OS.get_environment("POKEAETHER_DRATINI_STAGE") == "clean" else "platform"


static func render_scale_for(species: String, side: String) -> float:
	var species_scale: Dictionary = RENDER_SCALE.get(species.strip_edges().to_lower(), {})
	return float(species_scale.get(side, 1.0))


static func display_scale_multiplier_for(species: String) -> float:
	return float(DISPLAY_SCALE_MULTIPLIER.get(species.strip_edges().to_lower(), 1.0))


static func position_offset_for(species: String, side: String) -> Vector2:
	var species_offset: Dictionary = POSITION_OFFSET.get(species.strip_edges().to_lower(), {})
	return species_offset.get(side, Vector2.ZERO)
