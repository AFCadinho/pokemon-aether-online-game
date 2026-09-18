extends RefCounted

# Deliberately local and Dratini-only. The rendered derivatives live outside
# res:// and are never part of a release asset pack.
const OUTPUT_ROOT := "res://../.tmp/dratini-hd-battle-poc"
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
const RENDER_SCALE := {"front": 1.74, "back": 1.67}
const POSITION_OFFSET := {"front": Vector2(-10, 8), "back": Vector2(-12, 12)}

static var _move_index: Dictionary = {}
static var _frames_by_side: Dictionary = {}

static func is_enabled_for(species: String, side: String, shiny: bool) -> bool:
	return (
		OS.get_environment("POKEAETHER_DRATINI_HD") == "1"
		and species.strip_edges().to_lower() == "dratini"
		and side in ["front", "back"]
		and not shiny
	)


static func load_frames(side: String) -> SpriteFrames:
	if _frames_by_side.has(side):
		return _frames_by_side[side] as SpriteFrames
	var root := OS.get_environment("POKEAETHER_DRATINI_HD_DIR").strip_edges()
	if root.is_empty():
		root = ProjectSettings.globalize_path(OUTPUT_ROOT)
	var manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("manifest.json")))
	if not manifest_value is Dictionary:
		push_warning("Dratini HD POC: missing local manifest; using the normal sprite.")
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
			push_warning("Dratini HD POC: could not read %s; using the normal sprite." % image_path)
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
	_frames_by_side[side] = frames
	return frames


static func attack_action(move_name: String) -> String:
	if _move_index.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOVE_INDEX_PATH))
		if parsed is Dictionary:
			_move_index = parsed
	var key := move_name.strip_edges().to_lower().replace(" ", "-").replace("_", "-")
	var move_data: Dictionary = _move_index.get(key, {})
	return "physical_attack" if str(move_data.get("category", "")).to_lower() == "physical" else "special_attack"


static func speed_for(action: String) -> float:
	return float(ACTION_SPEED.get(action, 1.0))


static func stage_variant() -> String:
	return "clean" if OS.get_environment("POKEAETHER_DRATINI_STAGE") == "clean" else "platform"


static func render_scale_for(side: String) -> float:
	return float(RENDER_SCALE.get(side, 2.0))


static func position_offset_for(side: String) -> Vector2:
	return POSITION_OFFSET.get(side, Vector2.ZERO)
