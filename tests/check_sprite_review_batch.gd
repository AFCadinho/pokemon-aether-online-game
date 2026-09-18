extends SceneTree
## Focused local review-batch resolver check. Requires explicit preview catalog env.
const Assets := preload("res://scripts/battle/battle_ui/rendered_sprite_assets.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := OS.get_environment("POKEAETHER_RENDERED_PREVIEW_CATALOG")
	assert(not path.is_empty())
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(catalog.get("mode") == "preview")
	assert((catalog.get("entries") as Dictionary).size() == 15)
	for species: String in ["dragonite", "eevee", "roaring-moon"]:
		for side: String in ["front", "back"]:
			var frames := Assets.load_frames(species, side, false)
			assert(frames != null)
			assert(float(frames.get_meta("hd_poc_fps")) == 60.0)
			assert(frames.get_frame_count("idle") > 1)
			assert(frames.get_animation_loop("idle"))
			assert(not Assets.ensure_action_loaded(frames, "physical_attack"))
	assert(Assets.load_frames("gardevoir", "front", false) == null)
	var shiny := Assets.load_frames("eevee", "front", true)
	assert(shiny != null and shiny.get_frame_count("idle") > 1)
	assert(Assets.load_frames("meowth", "front", true) == null)
	print("SCVI review batch preview/fallback checks PASS")
	quit()
