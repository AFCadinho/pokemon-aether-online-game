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

	var reveal_branch := world_source.find("if is_zero_approx(target_alpha):")
	var content_fade := world_source.find("await content_tween.finished", reveal_branch)
	var background_fade := world_source.find("var background_tween := create_tween()", reveal_branch)
	_check(
		reveal_branch >= 0 and content_fade > reveal_branch and background_fade > content_fade,
		"the loading indicator disappears before the destination map is revealed"
	)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
