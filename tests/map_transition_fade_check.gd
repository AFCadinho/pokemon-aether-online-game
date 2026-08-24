extends SceneTree

const WORLD_PATH := "res://scripts/world/world.gd"

var failed := false


func _init() -> void:
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)
	_check(
		world_source.contains("const MAP_FADE_OUT_SECONDS := 0.60"),
		"the current map fades out gradually while loading begins"
	)
	_check(
		world_source.contains("const MAP_FADE_IN_SECONDS := 0.75"),
		"loaded maps use a gentle fade-in"
	)
	_check(
		world_source.contains("const MAP_LOADING_CONTENT_FADE_OUT_SECONDS := 0.12"),
		"the loading content has a dedicated short fade-out"
	)
	_check(
		world_source.contains("const MAP_TRANSITION_COVER_ALPHA := 0.80"),
		"the loading screen preserves a faint view of the previous map"
	)
	_check(
		world_source.contains("func _capture_map_transition_snapshot() -> bool:")
		and world_source.contains("ImageTexture.create_from_image(image)"),
		"map transitions freeze the rendered source map before replacing it"
	)

	var reveal_branch := world_source.find("if is_zero_approx(target_alpha):")
	var content_fade := world_source.find("await content_tween.finished", reveal_branch)
	var snapshot_fade := world_source.find("await snapshot_tween.finished", reveal_branch)
	var background_fade := world_source.find("var background_tween := create_tween()", reveal_branch)
	_check(
		reveal_branch >= 0
		and content_fade > reveal_branch
		and snapshot_fade > content_fade
		and background_fade > snapshot_fade,
		"loading content and the frozen source map clear before the destination brightens"
	)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
